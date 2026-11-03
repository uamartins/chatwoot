# uam: imagem do runner de specs (bin/uam-spec). Ruby do .ruby-version + nodejs para o ExecJS.
FROM ruby:3.4.4-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends nodejs postgresql-client \
    && rm -rf /var/lib/apt/lists/*
