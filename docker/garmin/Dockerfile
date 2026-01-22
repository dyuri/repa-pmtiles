FROM eclipse-temurin:17-jre-alpine

# Install required tools
RUN apk add --no-cache \
    bash \
    wget \
    unzip

# Set up working directory
WORKDIR /opt/garmin

# Download and extract mkgmap
RUN wget -q https://www.mkgmap.org.uk/download/mkgmap-latest.tar.gz && \
    tar xzf mkgmap-latest.tar.gz && \
    rm mkgmap-latest.tar.gz && \
    mv mkgmap-r* mkgmap

# Download and extract splitter
RUN wget -q https://www.mkgmap.org.uk/download/splitter-latest.tar.gz && \
    tar xzf splitter-latest.tar.gz && \
    rm splitter-latest.tar.gz && \
    mv splitter-r* splitter

# Download bounds and sea data for better maps
RUN mkdir -p /opt/garmin/data && \
    wget -q -O /opt/garmin/data/bounds.zip https://www.thkukuk.de/osm/data/bounds-latest.zip && \
    wget -q -O /opt/garmin/data/sea.zip https://www.thkukuk.de/osm/data/sea-latest.zip

# Create entrypoint script
COPY entrypoint.sh /opt/garmin/entrypoint.sh
RUN chmod +x /opt/garmin/entrypoint.sh

# Set up volumes
VOLUME ["/data", "/output", "/config", "/work"]

ENTRYPOINT ["/opt/garmin/entrypoint.sh"]
CMD ["--help"]
