"""
Synthetic source-system generator for the casino DWH.

Produces Parquet extracts that mimic what an ingestion layer (e.g. Debezium/CDC,
nightly OLTP dumps, ECB FX feed) would land in a data lake:

    data/raw/
      countries.parquet            reference data
      country_currencies.parquet   currency validity per country (HR: HRK -> EUR on 2023-01-01)
      currencies.parquet
      casinos.parquet
      gaming_machines.parquet
      games.parquet
      machine_games.parquet        machine <-> game installations (many-to-many, time-bounded)
      table_types.parquet
      gaming_tables.parquet
      clients_cdc.parquet          CDC change log of the client table (inserts + updates)
      casino_visits.parquet
      machine_gameplays.parquet
      table_gameplays.parquet
      fx_rates.parquet             ECB-style reference rates (units of currency per 1 EUR, business days only)

The generator is deterministic (fixed seed) so CI runs and tests are reproducible.

Usage:
    python generator/generate.py --out data/raw --start 2022-10-01 --end 2023-03-31 --scale 1.0
"""

from __future__ import annotations

import argparse
import time
from datetime import date, datetime, timedelta
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd
from faker import Faker

SEED = 42
EURO_ADOPTION_HR = date(2023, 1, 1)
HRK_FIXED_RATE = 7.53450  # official HRK/EUR conversion rate

COUNTRIES = [
    # iso2, iso3, name, region
    ("EE", "EST", "Estonia", "Baltics"),
    ("LV", "LVA", "Latvia", "Baltics"),
    ("LT", "LTU", "Lithuania", "Baltics"),
    ("HR", "HRV", "Croatia", "Balkans"),
]

CASINOS = [
    # code, name, country, city, timezone
    ("EE-TLN-01", "Northstar Tallinn", "EE", "Tallinn", "Europe/Tallinn"),
    ("EE-TRT-01", "Northstar Tartu", "EE", "Tartu", "Europe/Tallinn"),
    ("LV-RIX-01", "Northstar Riga Centre", "LV", "Riga", "Europe/Riga"),
    ("LV-RIX-02", "Northstar Riga Plaza", "LV", "Riga", "Europe/Riga"),
    ("LT-VNO-01", "Northstar Vilnius", "LT", "Vilnius", "Europe/Vilnius"),
    ("LT-KUN-01", "Northstar Kaunas", "LT", "Kaunas", "Europe/Vilnius"),
    ("HR-ZAG-01", "Northstar Zagreb", "HR", "Zagreb", "Europe/Zagreb"),
    ("HR-SPU-01", "Northstar Split", "HR", "Split", "Europe/Zagreb"),
]

GAMES = [
    # name, provider, category, theoretical RTP
    ("Book of Ra Deluxe", "Novomatic", "Video Slot", 0.95),
    ("Lucky Lady's Charm", "Novomatic", "Video Slot", 0.95),
    ("Sizzling Hot", "Novomatic", "Classic Slot", 0.955),
    ("Dolphin's Pearl", "Novomatic", "Video Slot", 0.951),
    ("Buffalo Gold", "Aristocrat", "Video Slot", 0.94),
    ("Lightning Link", "Aristocrat", "Hold & Spin", 0.93),
    ("Dragon Link", "Aristocrat", "Hold & Spin", 0.93),
    ("Queen of the Nile", "Aristocrat", "Video Slot", 0.946),
    ("Cleopatra", "IGT", "Video Slot", 0.95),
    ("Wheel of Fortune", "IGT", "Progressive", 0.92),
    ("Double Diamond", "IGT", "Classic Slot", 0.95),
    ("Starburst", "NetEnt", "Video Slot", 0.961),
    ("Gonzo's Quest", "NetEnt", "Video Slot", 0.96),
    ("Dead or Alive", "NetEnt", "Video Slot", 0.968),
    ("Hot Fruits 100", "EGT", "Classic Slot", 0.955),
    ("40 Super Hot", "EGT", "Classic Slot", 0.955),
    ("Shining Crown", "EGT", "Classic Slot", 0.953),
    ("Jacks or Better", "IGT", "Video Poker", 0.97),
    ("Deuces Wild", "IGT", "Video Poker", 0.97),
    ("Multi Roulette", "Interblock", "Electronic Roulette", 0.973),
    ("Mega Moolah", "Games Global", "Progressive", 0.88),
    ("Fire Joker", "Play'n GO", "Classic Slot", 0.96),
    ("Book of Dead", "Play'n GO", "Video Slot", 0.962),
    ("Sweet Bonanza", "Pragmatic Play", "Video Slot", 0.965),
]

MANUFACTURERS = [
    ("Novomatic", ["Gaminator Scorpion", "Dominator Curve", "V.I.P. Lounge"]),
    ("Aristocrat", ["MarsX", "Helix XT", "Arc Single"]),
    ("IGT", ["CrystalDual 27", "PeakSlant 49"]),
    ("EGT", ["P-42V Curved", "G-27 Dual"]),
    ("Interblock", ["Organic Roulette"]),
]

TABLE_TYPES = [
    # code, name, category, house_edge_hint
    ("POKER", "Texas Hold'em Poker", "Card", 0.03),
    ("BJ", "Blackjack", "Card", 0.02),
    ("RLT", "European Roulette", "Wheel", 0.027),
    ("BAC", "Punto Banco Baccarat", "Card", 0.012),
    ("CRP", "Craps", "Dice", 0.014),
]


def _write(df: pd.DataFrame, out: Path, name: str) -> None:
    """Write a DataFrame to Parquet through DuckDB (no pyarrow dependency)."""
    con = duckdb.connect()
    con.register("df", df)
    con.execute(f"COPY df TO '{out / name}.parquet' (FORMAT PARQUET, COMPRESSION ZSTD)")
    con.close()
    print(f"  {name:<22} {len(df):>10,} rows")


def currency_for(country: str, d: date) -> str:
    if country == "HR" and d < EURO_ADOPTION_HR:
        return "HRK"
    return "EUR"


def generate(out: Path, start: date, end: date, scale: float) -> None:
    rng = np.random.default_rng(SEED)
    fake = Faker(["et_EE", "lv_LV", "lt_LT", "hr_HR"])
    Faker.seed(SEED)
    out.mkdir(parents=True, exist_ok=True)
    days = pd.date_range(start, end, freq="D")
    extract_ts = datetime.combine(end + timedelta(days=1), datetime.min.time()) + timedelta(hours=2)

    print(f"Generating {start} .. {end} (scale={scale}) -> {out}")

    # ------------------------------------------------------------------ reference
    countries = pd.DataFrame(COUNTRIES, columns=["country_code", "iso3_code", "country_name", "region"])
    _write(countries, out, "countries")

    currencies = pd.DataFrame(
        [("EUR", "Euro", "€", 2), ("HRK", "Croatian kuna", "kn", 2)],
        columns=["currency_code", "currency_name", "symbol", "minor_units"],
    )
    _write(currencies, out, "currencies")

    country_currencies = pd.DataFrame(
        [
            ("EE", "EUR", date(2011, 1, 1), None),
            ("LV", "EUR", date(2014, 1, 1), None),
            ("LT", "EUR", date(2015, 1, 1), None),
            ("HR", "HRK", date(1994, 5, 30), date(2022, 12, 31)),
            ("HR", "EUR", EURO_ADOPTION_HR, None),
        ],
        columns=["country_code", "currency_code", "valid_from", "valid_to"],
    )
    _write(country_currencies, out, "country_currencies")

    # ------------------------------------------------------------------ casinos
    casinos = pd.DataFrame(CASINOS, columns=["casino_code", "casino_name", "country_code", "city", "timezone"])
    casinos.insert(0, "casino_id", np.arange(1, len(casinos) + 1))
    casinos["address"] = [fake.street_address() for _ in range(len(casinos))]
    casinos["opened_at"] = [date(2010 + i, 1 + i, 10) for i in range(len(casinos))]
    casinos["updated_at"] = extract_ts
    _write(casinos, out, "casinos")

    # ------------------------------------------------------------------ games
    games = pd.DataFrame(GAMES, columns=["game_name", "provider", "game_category", "theoretical_rtp"])
    games.insert(0, "game_id", np.arange(101, 101 + len(games)))
    games["updated_at"] = extract_ts
    _write(games, out, "games")

    # ------------------------------------------------------------------ gaming machines + installations
    machines, machine_games = [], []
    mid = 1000
    for c in casinos.itertuples():
        for _ in range(int(rng.integers(12, 19))):
            mid += 1
            manu, models = MANUFACTURERS[rng.integers(len(MANUFACTURERS))]
            machines.append(
                {
                    "machine_id": mid,
                    "casino_id": c.casino_id,
                    "asset_tag": f"{c.casino_code}-M{mid}",
                    "serial_number": f"{manu[:3].upper()}{rng.integers(10**7, 10**8)}",
                    "manufacturer": manu,
                    "model": models[rng.integers(len(models))],
                    "floor_zone": rng.choice(["Main Floor", "VIP", "Smoking Terrace", "Entrance"]),
                    "installed_at": start - timedelta(days=int(rng.integers(100, 2000))),
                    "decommissioned_at": None,
                    "updated_at": extract_ts,
                }
            )
            game_ids = rng.choice(games.game_id, size=int(rng.integers(3, 7)), replace=False)
            for i, gid in enumerate(game_ids):
                installed = start - timedelta(days=int(rng.integers(30, 400)))
                removed = None
                # ~20% of machines get one game swapped mid-period -> time-bounded bridge rows
                if i == 0 and rng.random() < 0.2:
                    removed = start + timedelta(days=int(rng.integers(30, 120)))
                    new_gid = int(rng.choice(np.setdiff1d(games.game_id, game_ids)))
                    machine_games.append(
                        {"machine_id": mid, "game_id": new_gid, "installed_at": removed, "removed_at": None}
                    )
                machine_games.append(
                    {"machine_id": mid, "game_id": int(gid), "installed_at": installed, "removed_at": removed}
                )
    machines = pd.DataFrame(machines)
    machine_games = pd.DataFrame(machine_games)
    _write(machines, out, "gaming_machines")
    _write(machine_games, out, "machine_games")

    # ------------------------------------------------------------------ tables
    table_types = pd.DataFrame(TABLE_TYPES, columns=["table_type_code", "table_type_name", "category", "house_edge"])
    table_types.insert(0, "table_type_id", np.arange(1, len(table_types) + 1))
    _write(table_types.drop(columns="house_edge"), out, "table_types")

    tables = []
    tid = 5000
    for c in casinos.itertuples():
        for n in range(int(rng.integers(4, 8))):
            tid += 1
            tt = table_types.iloc[rng.integers(len(table_types))]
            min_bet = float(rng.choice([2, 5, 10, 25]))
            tables.append(
                {
                    "table_id": tid,
                    "casino_id": c.casino_id,
                    "table_type_id": int(tt.table_type_id),
                    "table_number": f"T{n + 1:02d}",
                    "seats": int(rng.choice([6, 7, 9])),
                    "min_bet_eur": min_bet,
                    "max_bet_eur": min_bet * 200,
                    "updated_at": extract_ts,
                }
            )
    tables = pd.DataFrame(tables)
    _write(tables, out, "gaming_tables")

    # ------------------------------------------------------------------ clients (CDC log)
    n_clients = int(5000 * scale)
    casino_country = dict(zip(casinos.casino_id, casinos.country_code, strict=False))
    home_casino = rng.choice(casinos.casino_id, size=n_clients)
    # ~55% of the base registered before the observed window, rest registered during it
    pre = rng.random(n_clients) < 0.55
    reg_offsets = np.where(
        pre,
        -rng.integers(1, 1500, n_clients),
        rng.integers(0, len(days), n_clients),
    )
    reg_ts = [
        datetime.combine(start + timedelta(days=int(o)), datetime.min.time())
        + timedelta(minutes=int(rng.integers(10 * 60, 26 * 60)))
        for o in reg_offsets
    ]
    clients = []
    for i in range(n_clients):
        cc = casino_country[home_casino[i]]
        residence = cc if rng.random() < 0.85 else str(rng.choice([x[0] for x in COUNTRIES if x[0] != cc]))
        clients.append(
            {
                "client_id": 100000 + i,
                "first_name": fake.first_name(),
                "last_name": fake.last_name(),
                "birth_date": fake.date_of_birth(minimum_age=18, maximum_age=80),
                "gender": str(rng.choice(["M", "F"])),
                "document_type": str(rng.choice(["PASSPORT", "ID_CARD"], p=[0.35, 0.65])),
                "document_number": f"{residence}{rng.integers(10**7, 10**8)}",
                "document_country_code": residence,
                "residence_country_code": residence,
                "email": fake.free_email(),
                "registration_casino_id": int(home_casino[i]),
                "registered_at": reg_ts[i],
                "is_self_excluded": False,
            }
        )
    clients_df = pd.DataFrame(clients)
    cdc = clients_df.copy()
    cdc["op"] = "c"
    cdc["changed_at"] = cdc["registered_at"]

    # Updates within the window: residence moves, surname changes, self-exclusion.
    updates = []
    for row in clients_df.sample(frac=0.12, random_state=SEED).itertuples(index=False):
        r = row._asdict()
        first_possible = max(r["registered_at"], datetime.combine(start, datetime.min.time()))
        last_possible = datetime.combine(end, datetime.min.time())
        if first_possible >= last_possible:
            continue
        change_at = first_possible + timedelta(
            seconds=int(rng.integers(3600, int((last_possible - first_possible).total_seconds())))
        )
        kind = rng.choice(["move", "surname", "exclude"], p=[0.6, 0.3, 0.1])
        if kind == "move":
            r["residence_country_code"] = str(
                rng.choice([x[0] for x in COUNTRIES if x[0] != r["residence_country_code"]])
            )
        elif kind == "surname":
            r["last_name"] = fake.last_name()
        else:
            r["is_self_excluded"] = True
        r["op"] = "u"
        r["changed_at"] = change_at
        updates.append(r)
    cdc = pd.concat([cdc, pd.DataFrame(updates)], ignore_index=True)
    # Ingestion realities: some CDC events are delivered twice
    dupes = cdc.sample(frac=0.01, random_state=SEED + 1)
    cdc = pd.concat([cdc, dupes], ignore_index=True).sort_values(["changed_at", "client_id"])
    cdc["_ingested_at"] = extract_ts
    _write(cdc.reset_index(drop=True), out, "clients_cdc")

    # client state for the simulation (residence/exclusion changes don't block visits; keep it simple)
    reg_dates = np.array([t.date() for t in reg_ts])
    client_ids = clients_df.client_id.to_numpy()
    client_country = clients_df.residence_country_code.to_numpy()

    # ------------------------------------------------------------------ visits
    visits = []
    vid = 0
    for d in days:
        dd = d.date()
        weekend_boost = 1.35 if d.dayofweek in (4, 5) else 1.0
        eligible = reg_dates <= dd
        for c in casinos.itertuples():
            n = int(rng.poisson(45 * scale * weekend_boost))
            # prefer local residents
            mask = eligible & (client_country == c.country_code)
            pool = client_ids[mask] if mask.sum() > 20 else client_ids[eligible]
            if len(pool) == 0:
                continue
            who = rng.choice(pool, size=n, replace=True)  # same client can visit twice a day
            enter_min = rng.integers(10 * 60, 27 * 60, size=n)  # 10:00 .. 03:00 next day
            dur = rng.integers(20, 360, size=n)
            for k in range(n):
                vid += 1
                entered = datetime.combine(dd, datetime.min.time()) + timedelta(minutes=int(enter_min[k]))
                visits.append(
                    {
                        "visit_id": vid,
                        "client_id": int(who[k]),
                        "casino_id": c.casino_id,
                        "entered_at": entered,
                        "exited_at": entered + timedelta(minutes=int(dur[k])),
                    }
                )
    visits = pd.DataFrame(visits)
    # visits still in progress at extract time have no exit
    last_dt = datetime.combine(end, datetime.min.time()) + timedelta(days=1, hours=2)
    visits = visits[visits.entered_at < last_dt - timedelta(minutes=5)]  # nothing after the extract cut-off
    visits.loc[visits.exited_at > last_dt, "exited_at"] = pd.NaT
    # registration must precede first visit: a client registering today and visiting today is fine,
    # but drop visits that happen before the registration timestamp on the same day
    reg_map = dict(zip(clients_df.client_id, clients_df.registered_at, strict=False))
    visits = visits[visits.entered_at >= visits.client_id.map(reg_map)].reset_index(drop=True)
    _write(visits, out, "casino_visits")

    # ------------------------------------------------------------------ gameplays
    v_country = visits.casino_id.map(casino_country).to_numpy()
    v_enter = visits.entered_at.to_numpy()
    v_exit = visits.exited_at.fillna(pd.Timestamp(last_dt)).to_numpy()
    v_dur_s = ((v_exit - v_enter) / np.timedelta64(1, "s")).astype(np.int64)

    machines_by_casino = machines.groupby("casino_id").machine_id.apply(np.array).to_dict()
    tables_by_casino = tables.groupby("casino_id").table_id.apply(np.array).to_dict()
    installs = machine_games.copy()
    installs["removed_at"] = installs["removed_at"].fillna(date(2100, 1, 1))

    def explode(n_per_visit: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        idx = np.repeat(np.arange(len(visits)), n_per_visit)
        offs = (rng.random(len(idx)) * v_dur_s[idx]).astype(np.int64)
        ts = v_enter[idx] + offs.astype("timedelta64[s]")
        return idx, ts

    def fx_multiplier(idx: np.ndarray, ts: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        is_hrk = (v_country[idx] == "HR") & (ts < np.datetime64(EURO_ADOPTION_HR))
        return np.where(is_hrk, "HRK", "EUR"), np.where(is_hrk, 7.5, 1.0)

    def pick_per_casino(casino_ids: np.ndarray, assets_by_casino: dict) -> np.ndarray:
        """Vectorised uniform pick of an asset (machine/table) located in the given casino."""
        out_ = np.empty(len(casino_ids), dtype=np.int64)
        for cid, assets in assets_by_casino.items():
            m = casino_ids == cid
            out_[m] = assets[rng.integers(0, len(assets), size=m.sum())]
        return out_

    # ---- machines
    n_m = rng.poisson(14, size=len(visits))
    n_m[rng.random(len(visits)) < 0.15] = 0  # table-only players
    m_idx, m_ts = explode(n_m)
    m_casino = visits.casino_id.to_numpy()[m_idx]
    m_machine = pick_per_casino(m_casino, machines_by_casino)
    # pick a game that is installed on that machine at play date (time-bounded many-to-many)
    plays = pd.DataFrame({"i": np.arange(len(m_idx)), "machine_id": m_machine, "d": pd.to_datetime(m_ts).normalize()})
    inst = installs.assign(
        installed_at=pd.to_datetime(installs.installed_at), removed_at=pd.to_datetime(installs.removed_at)
    )
    cand = plays.merge(inst, on="machine_id")
    cand = cand[(cand.installed_at <= cand.d) & (cand.removed_at > cand.d)]
    cand = cand.assign(r=rng.random(len(cand))).sort_values(["i", "r"]).drop_duplicates("i")
    m_game = cand.sort_values("i").game_id.to_numpy()
    assert len(m_game) == len(m_idx), "every play must resolve to an installed game"
    cur, mult = fx_multiplier(m_idx, m_ts)
    bet = np.round(
        rng.choice([0.2, 0.5, 1, 2, 5, 10, 20], size=len(m_idx), p=[0.2, 0.25, 0.2, 0.15, 0.1, 0.07, 0.03]) * mult, 2
    )
    won = rng.random(len(m_idx)) < 0.40
    win_mult = 1 + rng.exponential(1.2, size=len(m_idx))
    jackpot = rng.random(len(m_idx)) < 0.0001
    win_mult[jackpot] = rng.integers(100, 1000, size=jackpot.sum())
    win = np.where(won, np.round(bet * win_mult, 2), 0.0)
    status = np.where(won, "win", "loss").astype(object)
    # games started in the last hour before extract are still ongoing
    ongoing = m_ts >= np.datetime64(last_dt - timedelta(hours=1))
    status[ongoing] = "ongoing"
    win[ongoing] = 0.0
    mg = pd.DataFrame(
        {
            "gameplay_id": np.arange(1, len(m_idx) + 1) + 10_000_000,
            "visit_id": visits.visit_id.to_numpy()[m_idx],
            "client_id": visits.client_id.to_numpy()[m_idx],
            "machine_id": m_machine,
            "game_id": m_game,
            "game_start_time": m_ts,
            "currency_code": cur,
            "bet_amount_money": bet,
            "win_amount_money": win,
            "game_status": status,
        }
    ).sort_values("game_start_time")
    _write(mg, out, "machine_gameplays")

    # ---- tables
    n_t = rng.poisson(2.5, size=len(visits))
    t_idx, t_ts = explode(n_t)
    t_casino = visits.casino_id.to_numpy()[t_idx]
    t_table = pick_per_casino(t_casino, tables_by_casino)
    cur, mult = fx_multiplier(t_idx, t_ts)
    min_bet = tables.set_index("table_id").min_bet_eur.reindex(t_table).to_numpy()
    bet = np.round(min_bet * rng.choice([1, 2, 4, 10], size=len(t_idx), p=[0.5, 0.3, 0.15, 0.05]) * mult, 2)
    won = rng.random(len(t_idx)) < 0.46
    win = np.where(
        won,
        np.round(bet * rng.choice([2, 2, 2, 2.5, 3, 36], size=len(t_idx), p=[0.5, 0.2, 0.15, 0.1, 0.049, 0.001]), 2),
        0.0,
    )
    status = np.where(won, "win", "loss").astype(object)
    undefined = rng.random(len(t_idx)) < 0.002  # voided hands / dealer errors
    status[undefined] = "undefined"
    win[undefined] = 0.0
    tg = pd.DataFrame(
        {
            "gameplay_id": np.arange(1, len(t_idx) + 1) + 50_000_000,
            "visit_id": visits.visit_id.to_numpy()[t_idx],
            "client_id": visits.client_id.to_numpy()[t_idx],
            "table_id": t_table,
            "game_start_time": t_ts,
            "currency_code": cur,
            "bet_amount_money": bet,
            "win_amount_money": win,
            "game_status": status,
        }
    ).sort_values("game_start_time")
    _write(tg, out, "table_gameplays")

    # ------------------------------------------------------------------ FX (ECB reference rates)
    # ECB publishes units of foreign currency per 1 EUR on TARGET business days only.
    # HRK publication stopped after 2022-12-30. Weekends/holidays must be forward-filled downstream.
    fx_days = pd.bdate_range(start - timedelta(days=10), min(end, date(2022, 12, 30)))
    hrk = 7.53 + np.cumsum(rng.normal(0, 0.002, size=len(fx_days)))
    fx = pd.DataFrame({"rate_date": fx_days.date, "currency_code": "HRK", "units_per_eur": np.round(hrk, 4)})
    fx["source"] = "ECB"
    _write(fx, out, "fx_rates")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--out", default="data/raw", type=Path)
    p.add_argument("--start", default="2022-10-01", type=date.fromisoformat)
    p.add_argument("--end", default="2023-03-31", type=date.fromisoformat)
    p.add_argument("--scale", default=1.0, type=float, help="volume multiplier (0.1 for quick CI runs)")
    a = p.parse_args()
    t0 = time.time()
    generate(a.out, a.start, a.end, a.scale)
    print(f"Done in {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
