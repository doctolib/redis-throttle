# Redis::Throttle

[Redis](https://redis.io/) based rate limit and concurrency throttling.


## Installation

Add this line to your application's Gemfile:

```ruby
gem "redis-throttle"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install redis-throttle


## Usage

### Concurrency Limit

``` ruby
# Allow 1 concurrent calls. If call takes more than 10 seconds, consider it
# gone (as if process died, or by any other reason did not called `#release`):
concurrency = Redis::Throttle.concurrency(:bucket_name,
  :limit => 1,
  :ttl   => 10
)

concurrency.acquire(:token => "abc") # => "abc"
concurrency.acquire(:token => "xyz") # => nil

concurrency.release(:token => "abc")

concurrency.acquire(:token => "xyz") # => "xyz"
```

### Rate Limit

``` ruby
# Allow 1 calls per 10 seconds:
rate_limit = Redis::Throttle.rate_limit(:bucket_name,
  :limit  => 1,
  :period => 10
)

rate_limit.acquire # => "6a6c6546-268d-4216-bcf3-3139b8e11609"
rate_limit.acquire # => nil

sleep 10

rate_limit.acquire # => "e2926a90-2cf4-4bff-9401-65f3a70d32bd"
```


### Multi-strategy

``` ruby
throttle = Redis::Throttle
  .concurrency(:db, :limit => 3, :ttl => 900)
  .rate_limit(:api_minutely, :limit => 1, :period => 60)
  .rate_limit(:api_hourly, :limit => 10, :period => 3600)

throttle.call(:token => "abc") do
  # do something if all strategies are resolved
end
```

You can also compose multiple throttlers together:

``` ruby
db_limiter  = Redis::Throttle.concurrency(:db, :limit => 3, :ttl => 900)
api_limiter = Redis::Throttle
  .rate_limit(:api_minutely, :limit => 1, :period => 60)
  .rate_limit(:api_hourly, :limit => 10, :period => 3600)

(db_limiter | api_limiter).call do
  # ...
end
```


### With ConnectionPool

If you're using [connection_pool](https://github.com/mperham/connection_pool),
you can pass its `#with` method as connection builder:

``` ruby
pool     = ConnectionPool.new { Redis.new }
throttle = Redis::Throttle.new(:redis => pool.method(:with))
```

### With Sidekiq

[Sidekiq](https://github.com/mperham/sidekiq): uses ConnectionPool, so you can
use the same approach:

``` ruby
throttle = Redis::Throttle.new(:redis => Sidekiq.redis_pool.method(:with))
```

Or, you can use its `.redis` method directly:

``` ruby
throttle = Redis::Throttle.new(:redis => Sidekiq.method(:redis))
```


## Compatibility

This library aims to support and is tested against:

* Ruby
  * MRI 2.6.x
  * MRI 2.7.x
  * JRuby 9.2.x
* Redis
  * 4.x
  * 5.x
  * 6.x
* [redis-rb](https://github.com/redis/redis-rb)
  * 4.2.x
  * 4.3.x
  * 4.4.x
* [redis-namespace](https://github.com/resque/redis-namespace)
  * 1.6.x
  * 1.7.x
  * 1.8.x

If something doesn't work on one of these versions, it's a bug.

This library may inadvertently work (or seem to work) on other Ruby versions,
however support will only be provided for the versions listed above.

If you would like this library to support another Ruby version or
implementation, you may volunteer to be a maintainer. Being a maintainer
entails making sure all tests run and pass on that implementation. When
something breaks on your implementation, you will be responsible for providing
patches in a timely fashion. If critical issues for a particular implementation
exist at the time of a major release, support for that Ruby version may be
dropped.

Same rules apply to *Redis*, *redis-rb*, and *redis-namespace* support.


## Development

After checking out the repo, run `bundle install` to install dependencies.
Then, run `bundle exec rake spec` to run the tests with ruby-rb client.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to [rubygems.org][].


## Contributing

* Fork redis-throttle
* Make your changes
* Ensure all tests pass (`bundle exec rake`)
* Send a merge request
* If we like them we'll merge them
* If we've accepted a patch, feel free to ask for commit access!


## Appreciations

Huge thanks to [@freemanoid][], [@petethepig][], and [@dervus][] for criticism
and suggestions.

[@freemanoid]: https://gitlab.com/freemanoid
[@petethepig]: https://gitlab.com/petethepig
[@dervus]: https://gitlab.com/dervus


## Copyright

Copyright (c) 2020-2021 Alexey Zapparov<br>
See [LICENSE.txt][] for further details.


[LICENSE.txt]: https://gitlab.com/ixti/redis-throttle/blob/master/LICENSE.txt
