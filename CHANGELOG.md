## 2.1.0
 - Preventing output blocking when the graphite server is down by introducing a resend_attempts counter.

## 2.0.3
 - Fixed empty/nil messages handling

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully,
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

## 1.0.2
 - Added support for sprintf in field formatting

## 1.0.1
 - Added support for nested hashes as values
