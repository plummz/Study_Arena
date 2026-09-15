FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY server/pom.xml ./pom.xml
COPY server/src ./src
RUN mvn -B -ntp package
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /build/target/study-arena-1.0.0.jar ./arena.jar
COPY web ./web
RUN mkdir /data && chown 10001:10001 /data
USER 10001:10001
ENV DATA_DIR=/data BIND=0.0.0.0 PORT=8080
EXPOSE 8080
ENTRYPOINT ["java","-Xms64m","-Xmx256m","-jar","arena.jar"]
