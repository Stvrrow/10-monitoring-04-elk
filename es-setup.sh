#!/usr/bin/env bash
# Настройка индексов logstash-* в кластере hot/warm.
set -euo pipefail
ES=${ES_URL:-http://localhost:9200}
TODAY=logstash-$(date -u +%Y.%m.%d)

# Реплику некуда разместить: tier data_content есть только на es-hot,
# а один и тот же шард нельзя держать дважды на одной ноде -> кластер yellow.
curl -s -XPUT -H 'Content-Type: application/json' "$ES/_index_template/logstash" -d '{
  "index_patterns": ["logstash-*"],
  "template": {"settings": {"number_of_replicas": 0}}
}'; echo
curl -s -XPUT -H 'Content-Type: application/json' "$ES/logstash-*/_settings" \
  -d '{"index": {"number_of_replicas": 0}}'; echo

# Индексы за прошлые дни переносим на warm-ноду, текущий остаётся на hot
for idx in $(curl -s "$ES/_cat/indices/logstash-*?h=index" | sort); do
  [ "$idx" = "$TODAY" ] && continue
  curl -s -XPUT -H 'Content-Type: application/json' "$ES/$idx/_settings" \
    -d '{"index.routing.allocation.include._tier_preference": "data_warm,data_hot"}'; echo " $idx -> warm"
done
