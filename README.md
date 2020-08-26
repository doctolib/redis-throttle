# Redis::Throttle

[Redis](https://redis.io/) based threshold and concurrency throttling.


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

### Limit concurrency

``` ruby
# Allow 1 concurrent calls. If call takes more than 10 seconds, consider it
# gone (as if process died, or by any other reason did not called `#release`):
concurrency = Redis::Throttle::Concurrency.new(:bucket_name,
  :limit => 1,
  :ttl   => 10
)

concurrency.acquire(Redis.current, :token => "abc") # => true
concurrency.acquire(Redis.current, :token => "xyz") # => false

concurrency.release(Redis.current, :token => "abc")

concurrency.acquire(Redis.current, :token => "xyz") # => true
```

### Limit threshold

``` ruby
# Allow 1 calls per 10 seconds:
threshold = Redis::Throttle::Threshold.new(:bucket_name,
  :limit  => 1,
  :period => 10
)

threshold.acquire(Redis.current) # => true
threshold.acquire(Redis.current) # => false

sleep 10

threshold.acquire(Redis.current) # => true
```

### Multi-Strategy

``` ruby
throttle = Redis::Throttle.new(:redis => Redis.current)

throttle << Redis::Throttle::Concurrency.new(:db, :limit => 3, :ttl => 900)
throttle << Redis::Throttle::Threshold.new(:api_minutely, :limit => 1, :period => 60)
throttle << Redis::Throttle::Threshold.new(:api_hourly, :limit => 10, :period => 3600)

throttle.call(Redis.current, :token => "abc") do
  # do something if all strategies are resolved
end
```


#### With ConnectionPool

If you're using [connection_pool](https://github.com/mperham/connection_pool),
e.g. in [Sidekiq](https://github.com/mperham/sidekiq) you can pass its `#with`
method as connection builder:

``` ruby
throttle = Redis::Throttle.new(:redis => Sidekiq.method(:redis))
```


## Compatibility

This library aims to support and is tested against:

* Ruby
  * MRI 2.4.x
  * MRI 2.5.x
  * MRI 2.6.x
  * MRI 2.7.x
  * JRuby 9.2.x
* Redis
  * 4.x
  * 5.x
  * 6.x
* [redis-rb](https://github.com/redis/redis-rb)
  * 4.0.x
  * 4.1.x
  * 4.2.x
* [redis-namespace](https://github.com/resque/redis-namespace)
  * 1.6.x
  * 1.7.x

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


## Copyright

Copyright (c) 2020 Alexey Zapparov<br>
See [LICENSE.txt][] for further details.


[LICENSE.txt]: https://gitlab.com/ixti/redis-throttle/blob/master/LICENSE.txt
