FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -q -e -B package -DskipTests

FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=build /app/target/streams-app-1.0.0.jar /app/app.jar
ENV KAFKA_BOOTSTRAP_SERVERS=kafka:9092
ENV INPUT_TOPIC=business.events
ENV OUTPUT_TOPIC=business.events.aggregated
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
