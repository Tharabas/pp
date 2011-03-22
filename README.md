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

The PrettyPrinter can be used to prettify JSON or XML inputs.

Simply call the file's name as the last argument of the `pp` call,
or use a piped call (eg. for curl)

<pre><code lang="bash"># prettyprint a file directly
pp file.json

# use pp on a pipe
cat file.xml | pp
curl -c www.domain.org/service/document/1 | pp
</code></pre>

### Try it
<pre><code lang="bash"># prettyprint without color
pp test.json

# prettyprint with color
pp -c test.json

# prettyprint piped
curl -s www.github.com | pp
</code></pre>

### Options

`-c` to colorize your Output. Colorized input is designed to improve readability.
The Output itself might not be a valid version of the original input,
like JSON Strings will be _unquoted_ and UTF-8 entities will be replaced by their chars.

## Why?

I wanted it for pretty printing JSON requests, namely for REST responses.

So JSON was focused, and XML might not entirely work currently (in fact it fails `pp http://www.google.com`).

## What else?

I tested it with PHP 5.3.3 on Mac OSX 10.6.

The default coloring scheme fits my needs
