package lab.kafka;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.Grouped;
import org.apache.kafka.streams.kstream.KGroupedStream;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.KTable;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;

import java.time.Duration;
import java.util.Locale;
import java.util.Properties;

/**
 * Трансформация (обогащение JSON), оконная агрегация count по eventType, вывод в отдельный топик.
 */
public final class BusinessEventStreamsApp {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    public static void main(String[] args) {
        String bootstrap = env("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092");
        String inTopic = env("INPUT_TOPIC", "business.events");
        String outTopic = env("OUTPUT_TOPIC", "business.events.aggregated");
        String appId = env("APPLICATION_ID", "business-event-aggregates");

        Properties props = new Properties();
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, appId);
        props.put(StreamsConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrap);
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass().getName());
        props.put(StreamsConfig.PROCESSING_GUARANTEE_CONFIG, StreamsConfig.AT_LEAST_ONCE);
        props.put(StreamsConfig.COMMIT_INTERVAL_MS_CONFIG, 5_000);

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, String> source = builder.stream(inTopic, Consumed.with(Serdes.String(), Serdes.String()));

        // Трансформация: нормализованный тип + сохранение полезной нагрузки для дальнейшего ключа
        KStream<String, String> transformed = source.mapValues(BusinessEventStreamsApp::transformEnvelope);

        KStream<String, String> keyed = transformed.selectKey((k, v) -> extractEventType(v));

        KGroupedStream<String, String> grouped = keyed.groupByKey(Grouped.with(Serdes.String(), Serdes.String()));

        TimeWindows windows = TimeWindows.ofSizeAndGrace(Duration.ofMinutes(1), Duration.ofSeconds(30));
        KTable<Windowed<String>, Long> counts = grouped.windowedBy(windows).count();

        counts.toStream()
                .map(BusinessEventStreamsApp::windowedCountToRow)
                .to(outTopic, Produced.with(Serdes.String(), Serdes.String()));

        KafkaStreams streams = new KafkaStreams(builder.build(), props);
        Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
        streams.start();
    }

    private static String env(String key, String def) {
        String v = System.getenv(key);
        return v == null || v.isBlank() ? def : v;
    }

    /** Трансформация: добавляем normalizedType (верхний регистр) в JSON-событие. */
    static String transformEnvelope(String raw) {
        try {
            JsonNode root = MAPPER.readTree(raw);
            if (!root.isObject()) {
                return raw;
            }
            ObjectNode o = (ObjectNode) root;
            String et = o.path("eventType").asText("");
            o.put("normalizedType", et.toUpperCase(Locale.ROOT));
            return MAPPER.writeValueAsString(o);
        } catch (Exception e) {
            return raw;
        }
    }

    static String extractEventType(String json) {
        try {
            JsonNode n = MAPPER.readTree(json);
            String et = n.path("eventType").asText("");
            return et.isEmpty() ? "UNKNOWN" : et;
        } catch (Exception e) {
            return "UNKNOWN";
        }
    }

    static KeyValue<String, String> windowedCountToRow(Windowed<String> wk, Long count) {
        try {
            long start = wk.window().start();
            long end = wk.window().end();
            String key = wk.key() + "|" + start;
            ObjectNode row = MAPPER.createObjectNode();
            row.put("event_type", wk.key());
            row.put("window_start", start);
            row.put("window_end", end);
            row.put("event_count", count);
            return new KeyValue<>(key, MAPPER.writeValueAsString(row));
        } catch (Exception e) {
            return new KeyValue<>("error|" + System.currentTimeMillis(), "{\"event_type\":\"ERROR\",\"window_start\":0,\"window_end\":0,\"event_count\":0}");
        }
    }
}
