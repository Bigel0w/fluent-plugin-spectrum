# Fluent::Plugin::Spectrum

fluent-plugin-spectrum is an input plug-in for [Fluentd](http://fluentd.org)

## Installation

These instructions assume you already have fluentd installed. 
If you don't, please run through [quick start for fluentd] (https://github.com/fluent/fluentd#quick-start)

Now after you have fluentd installed you can follow either of the steps below:

Add this line to your application's Gemfile:

    gem 'fluent-plugin-spectrum'

Or install it yourself as:

    $ gem install fluent-plugin-spectrum

## Usage
Add the following into your fluentd config.

	<source>
	 type spectrum # required, choosing the input plugin
	 endpoint spectrumapi.corp.yourdomain.net # required, FQDN of spectrum endpoint
	 user username # required, username for APIs
	 pass password # required, password for APIs
	 tag alert.spectrum # optional, tag to assign to events, default is alert.spectrum
	 interval 60 # optional, interval in seconds for how often to poll, defaults to 300
	 include_raw false # optional, include original object as key raw
	</source>

	<match alert.spectrum>
	 type stdout
	</match>

Now startup fluentd

    $ sudo fluentd -c fluent.conf &

Send a test

	TBD: Still need to create an example

## To Do
* Add retry login. On timeout/failure retry, how often, increasing delay? (how would that affect polling time, possible duplicates?)
* All flag to allow specifying spectrum attributes to get or get _ALL_
* Add flag to allow start date/time if users want to backfill data from a specific date. then start loop. 
* Add flag to disable loop, if users only wanted to backfill from datetime to now or specific end time. 
* Change loop to allow multiple runs to stack on eachother to avoid missing data?