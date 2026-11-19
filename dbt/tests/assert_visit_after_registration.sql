-- A client must be registered before entering a casino (all visitors are identified at the door).
select v.visit_id, v.client_id, v.entered_at, c.registered_at
from {{ ref('fct_casino_visit') }} v
join {{ ref('dim_client') }} c on c.client_sk = v.client_sk
where v.entered_at < c.registered_at
