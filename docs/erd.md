# Data model

Two levels of the model are documented here:

1. **Logical / source ERD**: the entities from the assignment plus the additional entities needed to answer the reporting questions correctly.
2. **Dimensional model (star schema)**: how the warehouse stores those entities for reporting.

---

## 1. Logical ERD (source entities)

Entities and attributes commented **added** are **not in the assignment**. They were added because the reporting questions can't be answered correctly without them (see [Why the extra entities](#why-the-extra-entities)).

```mermaid
erDiagram
    COUNTRY ||--o{ CASINO : "located in"
    COUNTRY ||--o{ COUNTRY_CURRENCY : "legal tender over time"
    CURRENCY ||--o{ COUNTRY_CURRENCY : ""
    CURRENCY ||--o{ FX_RATE : "quoted"
    CASINO ||--o{ GAMING_MACHINE : "hosts"
    CASINO ||--o{ GAMING_TABLE : "hosts"
    GAMING_TABLE_TYPE ||--o{ GAMING_TABLE : "classifies"
    GAMING_MACHINE ||--o{ GAMING_MACHINE_GAME : "has installed"
    GAME ||--o{ GAMING_MACHINE_GAME : "installed on"
    CLIENT ||--o{ CLIENT_HISTORY : "versions (SCD2)"
    CASINO ||--o{ CLIENT : "registered at"
    CLIENT ||--o{ CASINO_VISIT : "makes"
    CASINO ||--o{ CASINO_VISIT : "receives"
    CASINO_VISIT ||--o{ CLIENT_GAMING_MACHINE_GAME : "during"
    CASINO_VISIT ||--o{ CLIENT_GAMING_TABLE_GAME : "during"
    GAMING_MACHINE ||--o{ CLIENT_GAMING_MACHINE_GAME : "played on"
    GAME ||--o{ CLIENT_GAMING_MACHINE_GAME : "played"
    GAMING_TABLE ||--o{ CLIENT_GAMING_TABLE_GAME : "played at"
    CURRENCY ||--o{ CLIENT_GAMING_MACHINE_GAME : "denominated in"
    CURRENCY ||--o{ CLIENT_GAMING_TABLE_GAME : "denominated in"

    COUNTRY {
        char2 country_code PK "ISO 3166-1 alpha-2 - added"
        char3 iso3_code
        string country_name
        string region
    }
    CURRENCY {
        char3 currency_code PK "ISO 4217 - added"
        string currency_name
        int minor_units
    }
    COUNTRY_CURRENCY {
        char2 country_code PK, FK "added"
        char3 currency_code PK, FK
        date valid_from PK
        date valid_to "HR: HRK until 2022-12-31"
    }
    FX_RATE {
        date rate_date PK "added - ECB, business days"
        char3 currency_code PK, FK
        decimal units_per_eur
    }
    CASINO {
        int casino_id PK
        string casino_code UK
        string casino_name
        char2 country_code FK
        string city
        string timezone
    }
    GAMING_MACHINE {
        int machine_id PK
        int casino_id FK
        string asset_tag UK
        string serial_number
        string manufacturer
        string model
        date installed_at
        date decommissioned_at
    }
    GAME {
        int game_id PK
        string game_name
        string provider
        string game_category
        decimal theoretical_rtp
    }
    GAMING_MACHINE_GAME {
        int machine_id PK, FK
        int game_id PK, FK
        date installed_from PK
        date installed_to
    }
    GAMING_TABLE_TYPE {
        int table_type_id PK
        string table_type_code UK
        string table_type_name
    }
    GAMING_TABLE {
        int table_id PK
        int casino_id FK
        int table_type_id FK
        string table_number
        int seats
        decimal min_bet
        decimal max_bet
    }
    CLIENT {
        int client_id PK
        string document_type UK "natural key part 1"
        string document_number UK "natural key part 2"
        char2 document_country_code UK "natural key part 3"
        string first_name
        string last_name
        date birth_date
        char2 residence_country_code FK
        int registration_casino_id FK
        timestamp registered_at
        bool is_self_excluded
    }
    CLIENT_HISTORY {
        int client_id PK, FK "added - from CDC"
        timestamp valid_from PK
        timestamp valid_to
        string tracked_attributes "name, residence, document..."
    }
    CASINO_VISIT {
        bigint visit_id PK
        int client_id FK
        int casino_id FK
        timestamp entered_at
        timestamp exited_at
    }
    CLIENT_GAMING_MACHINE_GAME {
        bigint gameplay_id PK
        bigint visit_id FK
        int client_id FK
        int machine_id FK
        int game_id FK
        timestamp game_start_time
        char3 currency_code FK "added"
        decimal bet_amount_money
        decimal win_amount_money "0 on loss"
        string game_status "win, loss, ongoing"
    }
    CLIENT_GAMING_TABLE_GAME {
        bigint gameplay_id PK
        bigint visit_id FK
        int client_id FK
        int table_id FK
        timestamp game_start_time
        char3 currency_code FK "added"
        decimal bet_amount_money
        decimal win_amount_money "0 on loss"
        string game_status "win, loss, undefined"
    }
```

### Minimum attributes, with reasons

| Need | Attribute(s) | Why |
|---|---|---|
| Identify a customer uniquely | `document_type + document_number + document_country_code` | `client_id` is only the source-system key. A physical person is identified by their ID document, and document numbers are only unique within the issuing country. Every client is ID-checked at the door, so this data always exists. |
| Report money in EUR | `currency_code` on every gameplay + `FX_RATE` + `COUNTRY_CURRENCY` | Transactions are in local currency. Croatia used **HRK until 2022-12-31** and EUR afterwards, so the currency can't be derived from the country alone. It has to be stored on the transaction. |
| "per country at any given date" | `residence_country_code` with history (`CLIENT_HISTORY`) | Clients move. A point-in-time answer needs to know where the client lived *on that date*, which means SCD type 2. |
| "new registrations" | `registered_at`, `registration_casino_id` | A registration is separate from the first visit. |
| "visits per day" | `entered_at`, `exited_at` | Visits are counted per gaming day. |
| "profit" | `bet_amount_money`, `win_amount_money`, `game_status` | Profit (GGR) = bets − wins, counted on **settled** rounds only (`ongoing` / `undefined` rounds are excluded). |
| A game installed on several machines | `GAMING_MACHINE_GAME` with validity dates | A many-to-many relationship, and the installed games change over time. |

### Why the extra entities

* **Country**: casinos operate in 4 countries, and Q1 groups by country. A reference table gives ISO codes, names and a region attribute that can be extended.
* **Currency + Country_Currency**: needed for correct EUR reporting. *Croatia adopted the euro on 1 Jan 2023*. Without a time-bounded currency mapping, December 2022 HRK amounts would be summed as if they were euros, overstating them about 7.5 times.
* **FX_Rate**: daily ECB reference rates. The ECB doesn't publish on weekends or holidays, and stopped quoting HRK after 30 Dec 2022, so the warehouse forward-fills gaps and uses the irrevocable rate **7.53450** after the changeover.
* **Client_History (SCD2)**: answers "*at any given date*" correctly when a client's residence country changes.
* **Date (in the warehouse)**: a conformed calendar. Gaming day, ISO week and weekend flags are used by every "per day" question.

---

## 2. Dimensional model (star schema)

```mermaid
erDiagram
    DIM_DATE ||--o{ FCT_CASINO_VISIT : visit_date_key
    DIM_DATE ||--o{ FCT_MACHINE_GAMEPLAY : game_date_key
    DIM_DATE ||--o{ FCT_TABLE_GAMEPLAY : game_date_key
    DIM_DATE ||--o{ FCT_FX_RATE_DAILY : date_key
    DIM_CLIENT ||--o{ FCT_CASINO_VISIT : client_sk
    DIM_CLIENT ||--o{ FCT_MACHINE_GAMEPLAY : client_sk
    DIM_CLIENT ||--o{ FCT_TABLE_GAMEPLAY : client_sk
    DIM_CASINO ||--o{ FCT_CASINO_VISIT : casino_sk
    DIM_CASINO ||--o{ FCT_MACHINE_GAMEPLAY : casino_sk
    DIM_CASINO ||--o{ FCT_TABLE_GAMEPLAY : casino_sk
    DIM_CASINO ||--o{ DIM_GAMING_MACHINE : casino_sk
    DIM_CASINO ||--o{ DIM_GAMING_TABLE : casino_sk
    DIM_COUNTRY ||--o{ DIM_CASINO : country_code
    DIM_GAMING_MACHINE ||--o{ FCT_MACHINE_GAMEPLAY : machine_sk
    DIM_GAME ||--o{ FCT_MACHINE_GAMEPLAY : game_sk
    DIM_GAMING_MACHINE ||--o{ BRIDGE_MACHINE_GAME : machine_sk
    DIM_GAME ||--o{ BRIDGE_MACHINE_GAME : game_sk
    DIM_GAMING_TABLE ||--o{ FCT_TABLE_GAMEPLAY : table_sk
    DIM_CURRENCY ||--o{ FCT_MACHINE_GAMEPLAY : currency_sk
    DIM_CURRENCY ||--o{ FCT_TABLE_GAMEPLAY : currency_sk
    DIM_CURRENCY ||--o{ FCT_FX_RATE_DAILY : currency_sk

    DIM_CLIENT {
        string client_sk PK "hash(client_id, valid_from)"
        int client_id "source key"
        string person_key "hash(document)"
        string residence_country_code
        date registration_date
        int registration_casino_id
        timestamp valid_from
        timestamp valid_to
        bool is_current
    }
    DIM_DATE {
        int date_key PK "yyyymmdd"
        date date_day
        int iso_week
        bool is_weekend
    }
    DIM_CASINO {
        string casino_sk PK
        int casino_id
        string casino_name
        string country_code
    }
    DIM_GAMING_MACHINE {
        string machine_sk PK
        string asset_tag
        string manufacturer
        string casino_sk FK
    }
    DIM_GAME {
        string game_sk PK
        string game_name
        string provider
    }
    BRIDGE_MACHINE_GAME {
        string machine_sk FK
        string game_sk FK
        date installed_from
        date installed_to
    }
    DIM_GAMING_TABLE {
        string table_sk PK
        string table_number
        string table_type_code "denormalised"
        string casino_sk FK
    }
    FCT_CASINO_VISIT {
        bigint visit_id PK
        int visit_date_key FK
        string client_sk FK
        string casino_sk FK
        int duration_minutes
    }
    FCT_MACHINE_GAMEPLAY {
        bigint gameplay_id PK
        int game_date_key FK
        string client_sk FK
        string casino_sk FK
        string machine_sk FK
        string game_sk FK
        string currency_sk FK
        decimal bet_amount_local
        decimal win_amount_local
        decimal bet_amount_eur
        decimal win_amount_eur
        decimal ggr_eur
        string game_status
    }
    FCT_TABLE_GAMEPLAY {
        bigint gameplay_id PK
        int game_date_key FK
        string client_sk FK
        string casino_sk FK
        string table_sk FK
        string currency_sk FK
        decimal bet_amount_eur
        decimal win_amount_eur
        decimal ggr_eur
    }
    FCT_FX_RATE_DAILY {
        int date_key PK
        string currency_sk PK
        decimal units_per_eur
        string rate_type
    }
```

### Question → model coverage

| # | Question | Answered by | Key mechanics |
|---|---|---|---|
| 1 | Unique customers per country at any date | `rpt_clients_by_country_daily` | Date spine × SCD2 point-in-time join. Two readings are given: by residence country, and by the country of the casinos visited |
| 2 | New registrations in the last 7 days | `rpt_new_registrations_last_7_days` | `report_date` variable (defaults to the latest activity date), split per casino plus a total |
| 3 | Unique visits per day per casino | `rpt_casino_daily_visits` | `count(distinct client_id)` per gaming day |
| 4 | Customer total bet (EUR) per day per casino | `rpt_client_casino_daily_gaming.total_bet_eur` | FX conversion in the facts |
| 5 | Customer total win (EUR) per day per casino | `rpt_client_casino_daily_gaming.total_win_eur` | as above |
| 6 | Machine with most games per day | `rpt_top_assets_daily` (machine / most_games_played) | `rank()`; ties are kept |
| 7 | Machine with most profit per day | `rpt_top_assets_daily` (machine / most_profit_eur) | GGR on settled rounds |
| 8 | Table with most games per day | `rpt_top_assets_daily` (table / most_games_played) | |
| 9 | Table with most profit per day | `rpt_top_assets_daily` (table / most_profit_eur) | |
