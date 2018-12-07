# Elastic stack samples for the IBM MQ Appliance
These samples can be used to consume IBM MQ Appliance log events.

To use these samples:

1. Create an instance of Elasticsearch
2. Define the mapping to be used when creating an IBM MQ Appliance index
3. Create an instance of Logstash using the sample pipeline
4. Configure a syslog log target to stream IBM MQ Appliance log events to Logstash
5. Create an instance of Kibana to visualize the log events in Elasticsearch

## elasticsearch-mq-appliance-template.json
Elasticsearch index mapping template for IBM MQ Appliance log events

## logstash-mq-appliance.conf
Logstash pipeline for processing IBM MQ Appliance log events
