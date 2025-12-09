FROM ruby:3.1.4

ENV LANG C.UTF-8
ENV TZ Asia/Tokyo

RUN apt-get update -qq && apt-get install -y \
    postgresql-client vim nano git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

COPY . .

CMD ["bash"]
