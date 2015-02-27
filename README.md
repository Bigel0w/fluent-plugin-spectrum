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
   type spectrum															# required, choosing the input plugin
   endpoint spectrumapi.corp.yourdomain.net		# required, FQDN of spectrum endpoint
   user username															# required, username for APIs
   pass password															# required, password for APIs
   tag alert.spectrum													# optional, tag to assign to events, default is alert.spectrum
   interval 60																# optional, interval in seconds for how often to poll, defaults to 300
   include_raw false													# optional, include original object as key raw
  </source>

  <match alert.spectrum>
   type stdout
  </match>

Now startup fluentd

    $ sudo fluentd -c fluent.conf &

Send a test 
    TBD

## To Do
Things left to do, not in any particular order.