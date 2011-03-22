# pp - CommandLine PrettyPrinter

## HowTo

### Requirements

You need PHP 5.3+ to run the script.

### Install

When in the `/pp/` folder:

<pre><code lang="bash"># create the shortcut
ln -s $(pwd)/pp /usr/local/bin/pp
# allow execution
chmod +x pp
</code></pre>

### Use it

### Try it
<pre><code lang="bash">pp test.json
pp -c test.json

curl -s www.github.com | pp
</code></pre>

### Options

`-c` to colorize your Output. Colorized input is designed to improve readability.
The Output itself might not be a valid version of the original input,
like JSON Strings will be _unquoted_ and UTF-8 entities will be replaced by their chars.

## Why?

I wanted it for pretty printing JSON requests, 
but accidently it could be used to prettyprint XMLs.

## What else?

I tested it with PHP 5.3.3 on Mac OSX 10.6.

The default coloring scheme fits my needs
