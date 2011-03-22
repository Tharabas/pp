#!/usr/bin/php
<?php

/**
 * Shell PrettyPrinter @ github.com/Tharabas/pp
 *
 * CLI pretty printing of JSON and XML files (currently)
 * 
 * Copyright (C) 2001-2011 by Tharabas <free.software@tharabas.de>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
class Shell {
  const ALIGN_OFF    = 0;
  const ALIGN_LEFT   = 1;
  const ALIGN_RIGHT  = 2;
  const ALIGN_CENTER = 3;

  const BBCODE_OPEN  = '[';
  const BBCODE_CLOSE = ']';
  const BBCODE_END   = '/';

  const META_START   = "\033[";
  const META_END     = "m";

  /** Unix-Shell-Styles. */
  private static $unix_shell_styles = array(
    'normal'    => 0,
    'default'   => 0,
    'bold'      => 1,
    'underline' => 4,
    'blink'     => 5,
    'invert'    => 7
    );

  /** Unix-Shell-Colors. */
  private static $unix_shell_colors = array(
    'black'   => 0,
    'red'     => 1,
    'green'   => 2,
    'yellow'  => 3,
    'blue'    => 4,
    'magenta' => 5,
    'cyan'    => 6,
    'teal'    => 6,
    'white'   => 7
    );

  private static $verbose = false;

  public static function isVerbose() {
    return self::$verbose;
  }

  public static function setVerbose($verbose = true) {
    self::$verbose = !!$verbose;
  }

  private static $blockLevel = 0;

  private static function meta($c = null) {
    return self::META_START . $c . self::META_END;
  }

  /**
   * Used to style unix shell output
   *
   * @param $text String the to be colored string
   * @param $style the style or style name
   * @param $color the color or color name
   * @return String the colored text
   */
  public static function style($text, $style = 0, $color = -1) {
    $c_end = self::meta(0);
    $c_start = self::META_START;

    if (is_string($style)) {
      if (isset(self::$unix_shell_colors[$style])) {
        $c_start .= '0';
        $color = $style;
      } else if (isset(self::$unix_shell_styles[$style])) {
        $c_start .= self::$unix_shell_styles[$style];
      } else {
        $c_start .= '0';
      }
    }

    if ($color != -1) {
      if (is_string($style) && isset(self::$unix_shell_colors[$color])) {
        $color = self::$unix_shell_colors[$color];
      }
      $c_start .= ';' . ($color + 30);
    }
    $c_start .= self::META_END;

    return $c_start . $text . $c_end;
  }

  public static function dump($text, $maxWidth = 80) {
    echo str_repeat('-', $maxWidth) . "\n" . $text . "\n" . str_repeat('-', $maxWidth) . "\n";
  }

  public static function styleText($text) {
    $re = '';
    $last_pos = 0;
    $pos = 0;

    while (($last_pos < strlen($text)
      && ($pos = strpos($text, self::BBCODE_OPEN, $last_pos)) !== false))
    {
      $re .= substr($text, $last_pos, $pos - $last_pos);

      $open_end = strpos($text, self::BBCODE_CLOSE, $pos);
      $opening_tag = substr($text, $pos, $open_end - $pos + 1);

      $args = explode(':', substr($opening_tag, 1, -1));
      $cmd = array_shift($args);

      $closing_tag = self::BBCODE_OPEN . self::BBCODE_END . $cmd . self::BBCODE_CLOSE;

      $content = $opening_tag;
      $next_pos = $open_end;

      while ($next_pos !== false && self::weightTags($content, $cmd) != 0) {
        $next_pos = strpos($text, $closing_tag, $next_pos);
        $content = substr($text, $open_end + 1, $next_pos - $open_end - 1);
      }

      if ($next_pos === false) {
        // no matching closing tag -> ignore this one
        $re .= substr($text, $pos, $open_end - $pos);
        $last_pos = $open_end;
      } else {
        array_unshift($args, $content);

        // the following part could be dynamized
        if ($cmd == 'c') {
          $re .= call_user_func_array('self::style', $args);
        } else if ($cmd == 'b') {
          array_shift($args);
          array_unshift($args, $content, 'bold');
          $re .= call_user_func_array('self::style', $args);
        } else if ($cmd == '>') {
          $re .= call_user_func_array('self::getRightPadString', $args);
        } else if ($cmd == '<') {
          $re .= call_user_func_array('self::getLeftPadString', $args);
        } else if ($cmd == 'frame') {
          $re .= call_user_func_array('self::frame', $args);
        } else {
          $re .= call_user_func_array('self::align', $args);
        }
        $last_pos = $next_pos + strlen($cmd) + 3;
      }
    }

    if ($last_pos < strlen($text)) {
      $re .= substr($text, $last_pos);
    }

    return $re;
  }

  public static function weightTags($content, $cmd, $countNegative = false) {
    $opening_tag = self::BBCODE_OPEN . $cmd;
    $closing_tag = self::BBCODE_OPEN . self::BBCODE_END . $cmd . self::BBCODE_CLOSE;

    // dirty for now ... another of these "I'll regret this" sentences ...
    $weight = self::strcount($content, $opening_tag) - self::strcount($content, $closing_tag);
    if (!$countNegative) {
      $weight = max($weight, 0);
    }
    return $weight;
  }

  public static function contentBetween($context, $start, $end) {
    if (($spos = strpos($context, $start)) === false) {
      return null;
    }
    if (($epos = strrpos($context, $end, $spos)) === false) {
      return null;
    }
    return substr($context, $spos + strlen($start), $epos - $spos - strlen($end));
  }

  public static function strcount($haystack, $needle) {
    $re = 0;
    $pos = -1;
    while (($pos = strpos($haystack, $needle, $pos + 1)) !== false) {
      $re++;
    }
    return $re;
  }

  public static function stripBBTags($text) {
    return preg_replace("/\[\/?[a-zA-Z:_-]+\]/", '', $text);
  }

  public static function cleanstr($text) {
    $tmp = preg_replace("/\033\[\d+(?:;\d+)?m/", '', $text);
    return self::stripBBTags($tmp);
  }

  public static function rstrlen($text) {
    return strlen(self::cleanstr($text));
  }

  public static function maxKeyLen($array) {
    $max = 0;
    foreach ($array as $k => $v) {
      $max = max($max, strlen($k));
    }
    return $max;
  }

  public static function maxValLen($array) {
    $max = 0;
    foreach ($array as $k => $v) {
      $max = max($max, strlen($v));
    }
    return $max;
  }

  public static function getPaddedString($string, $minLength = 8, $leftPadding = false, $char = ' ') {
    if (strlen($char) == 0) {
      return $string;
    }
    $re = $string;
    while (strlen($re) < $minLength) {
      if ($leftPadding) {
        $re = $char . $re;
      } else {
        $re .= $char;
      }
    }

    return $re;
  }

  public static function getLeftPadString($string, $minLength = 8, $char = ' ') {
    return self::getPaddedString($string, $minLength, true, $char);
  }

  public static function getRightPadString($string, $minLength = 8, $char = ' ') {
    return self::getPaddedString($string, $minLength, false, $char);
  }

  public static function frame($text, $minWidth = 0, $maxWidth = 80) {
    $text = self::styleText($text);
    $minWidth = max($minWidth, self::rstrlen($text));

    $ol = array();
    $w = 0;

    foreach (explode("\n", $text) as $line) {
      while (self::rstrlen($line) > $maxWidth) {
        $pos = $maxWidth;
        while (($npos = strpos(' ', $line)) !== false && $npos < $maxWidth) {
          $pos = $npos;
        }
        $ol[] = substr($line, 0, $pos);
        $line = '  ' . substr($line, $pos);
      }

      $ol[] = $line;
    }

    foreach ($ol as $line) {
      $w = max($w, self::rstrlen($line));
    }

    $alignStack = array(self::ALIGN_LEFT);
    $re = '';

    foreach ($ol as $line) {
      $l = $line;

      if (($apos = strpos($line, self::META_START . 'a')) !== false) {
        $cpos = strpos($line, self::META_END, $apos);
        $a = intval(substr($line, $apos + strlen(self::META_START) + 1, 1));
        $l = substr($l, 0, $apos) . substr($l, $cpos + 1);
        if ($a) {
          array_unshift($alignStack, $a);
        } else {
          if (count($alignStack)) {
            array_shift($alignStack);
            if (empty($l)) {
              $l = null;
            }
          }
        }
      }

      if ($l != null) {
        if (($wlen = $w - self::rstrlen($l)) > 0) {
          $align = $alignStack[0];
          if ($align == self::ALIGN_LEFT) {
            // add whitespaces at the right side
            $l = $l . str_repeat(' ', $wlen);
          } else if ($align == self::ALIGN_RIGHT) {
            $l = str_repeat(' ', $wlen) . $l;
          } else {
            $l = str_repeat(' ', floor($wlen / 2)) . $l . str_repeat(' ', ceil($wlen / 2));
          }
        }
        $re .= '| ' . $l . ' |' . "\n";
      }
    }

    $h = '+' . str_repeat('-', $w + 2) . '+';

    return "$h\n$re$h";
  }

  private static function align($content, $align) {
    $v = array(
      'left'   => self::ALIGN_LEFT,
      'right'  => self::ALIGN_RIGHT,
      'center' => self::ALIGN_CENTER
    );

    $c = self::styleText($content);

    if (isset($v[$align])) {
      $c = self::meta('a' . $v[$align]) . $c . "\n" . self::meta('a0');
    }

    return $c;
  }

  public static function indent($text, $depth = 1, $char = '  ') {
    $tok = str_repeat($char, $depth);
    return $tok . str_replace("\n", "\n$tok", $text);
  }

  public static function openBlock($name = null, $opener = '{') {
    if ($name != null) {
      self::echoln($name . ' ' . $opener);
    }
    self::$blockLevel++;
  }

  public static function closeBlock($msg = null, $closer = '}') {
    self::$blockLevel = max(0, self::$blockLevel - 1);
    if ($msg == null) {
      $msg = $closer;
    } else {
      $msg = $closer . ' ' . $msg;
    }
    self::echoln($msg);
  }

  public static function echos($msg) {
    if (!empty($msg)) {
      echo self::styleText(self::indent($msg, self::$blockLevel));
    }
  }

  public static function echoln($msg) {
    if (!empty($msg)) {
      echo self::styleText(self::indent($msg, self::$blockLevel) . "\n");
    }
  }

  public static function sow() {
    ob_start();
  }

  /**
   * Always wanted to have a function that is called 'reap'
   * Sticking to the farm theme there are several functions around here that fit in
   */
  public static function reap() {
    //$contents = '';
    $contents = ob_get_contents();
    ob_end_clean();
    return $contents;
  }

  public static function harvest($depth = 1, $char = ' ') {
    echo self::indent(self::reap(), $depth, $char);
  }

  public static function farm() {
    self::sow();

    $args = func_get_args();
    $method = array_shift($args);

    $result = call_user_func_array($method, $args);

    self::harvest();

    return $result;
  }
  
  public static function lastFileOrStdIn() {
    global $argc, $argv;
    
    $filename = $argv[$argc - 1];
    if ($argc > 1 && $filename[0] != '-') {
      return file_get_contents($filename);
    }
    return file_get_contents('php://stdin');
  }
}

// echo and echo-if-verbose
function xo($text) {
  echo Shell::echoln($text);
}
function vxo($text) {
  if (Shell::isVerbose()) xo($text);
}
function xos($text) {
  echo Shell::echos($text);
}
function xoc($text) {
  echo Shell::styleText($text);
}
function xon($text) {
  echo Shell::styleText($text) . "\n";
}
function c($text, $color) { 
  return Shell::style($text, 'normal', $color);
}
function b($text, $color) {
  return Shell::style($text, 'bold', $color);
}
function hasArg($arg) {
  global $argc, $argv;
  if (!is_array($arg)) $arg = array($arg);
  foreach ($arg as $a) {
    if (in_array($a, $argv)) return true;
  }
  return false;
}

/**
 * JSON PrettyPrinter in a slightly modified version of umbrae@gmail.com
 * source from http://www.php.net/manual/de/function.json-encode.php#80339
 */
function json_pp($json_obj) {
  $tab = "  ";
  $new_json = "";
  $indent_level = 0;
  $in_string = FALSE;

  if ($json_obj === FALSE) {
    return FALSE;
  }

  $json = json_encode($json_obj);
  $len = strlen($json);

  for ($c = 0; $c < $len; $c++) {
    $char = $json[$c];
    switch ($char) {
      case '{':
      case '[':
        if (!$in_string) {
          $new_json .= $char . "\n" . str_repeat($tab, $indent_level+1);
          $indent_level++;
        } else {
          $new_json .= $char;
        }
        break;

      case '}':
      case ']':
        if (!$in_string) {
          $indent_level--;
          $new_json .= "\n" . str_repeat($tab, $indent_level) . $char;
        } else {
          $new_json .= $char;
        }
        break;

      case ',':
        if (!$in_string) {
          $new_json .= ",\n" . str_repeat($tab, $indent_level);
        } else {
          $new_json .= $char;
        }
        break;

      case ':':
        if (!$in_string) {
          $new_json .= ": ";
        } else {
          $new_json .= $char;
        }
        break;
      case '"':
        if ($c > 0 && $json[$c-1] != '\\') {
          $in_string = !$in_string;
        }

      default:
        $new_json .= $char;
        break;
    }
  }

  // remove space in empty arrays/objects
  $new_json = preg_replace("/\[\s*\]/m", '[]', $new_json);
  $new_json = preg_replace("/\{\s*\}/m", '{}', $new_json);
  $new_json = preg_replace("/\},\n\s*\{/m", '}, {', $new_json);

  return $new_json;
} // END encodePretty

/** Prettifies an XML string into a human-readable and indented work of art
 *  @param string $xml The XML as a string
 *  @param boolean $html_output True if the output should be escaped (for use in HTML)
 */
function xml_pp($xml, $html_output=false) {
    $xml_obj = new SimpleXMLElement($xml);
    $level = 2;
    $indent = 0; // current indentation level
    $pretty = array();
    
    // get an array containing each XML element
    $xml = explode("\n", preg_replace('/>\s*</', ">\n<", $xml_obj->asXML()));

    // shift off opening XML tag if present
    if (count($xml) && preg_match('/^<\?\s*xml/', $xml[0])) {
      $pretty[] = array_shift($xml);
    }

    foreach ($xml as $el) {
      if (preg_match('/^<([\w])+[^>\/]*>$/U', $el)) {
          // opening tag, increase indent
          $pretty[] = str_repeat(' ', $indent) . $el;
          $indent += $level;
      } else {
        if (preg_match('/^<\/.+>$/', $el)) {            
          $indent -= $level;  // closing tag, decrease indent
        }
        if ($indent < 0) {
          $indent += $level;
        }
        $pretty[] = str_repeat(' ', $indent) . $el;
      }
    }   
    $xml = implode("\n", $pretty);   
    return ($html_output) ? htmlentities($xml) : $xml;
}

if (hasArg('-h')) {
  xo(<<<HELP
[b:red]Tharabas[/b] [b:yellow]JSON PrettyPrinter[/b]
Usage: pp [options] <file>

  -c   colorize output
  -h   this help

Example:
  pp local/data.json
  pp -c http://path/to/your/data.json
HELP
  );
  exit(0);
}

// const CONFIG_PATH = "~/.pp.conf";
// 
// if (file_exists(CONFIG_PATH)) {
//   $conf = json_decode(file_get_contents(CONFIG_PATH));
// }

// look for JSON content
$code = Shell::lastFileOrStdIn();

if ($code[0] == '{') {
  // user JSON
  $json = json_pp(json_decode($code));

  if (hasArg('-a')) {
    // TODO align blocks
  }

  if (hasArg('-c')) {
    // colorize blocks
    $colorizer = array(
      "/\"(.+)\":/" => function($m) { 
        return c($m[1], 'teal').':'; 
      },
      "/(\s+|: )(\".+\")(,?\n)/" => function($m) { 
        return $m[1] . c(json_decode($m[2]), 'green') . $m[3]; 
      },
      "/(\s+|: )(\d+(?:\.\d+)?)(,?\n)/" => function($m) { 
        return $m[1] . c($m[2], 'yellow') . $m[3]; 
      },
      "/(\s+|: )(true|false|null)(,?\n)/" => function($m) { 
        return $m[1] . c($m[2], 'red') . $m[3]; 
      }
    );

    foreach ($colorizer as $rx => $callback) $json = preg_replace_callback($rx, $callback, $json);
  }

  echo $json . "\n";
} else if ($code[0] == '<') {
  $xml = xml_pp($code);
  
  if (hasArg('-c')) {
    // colorize blocks
    $colorizer = array(
      "/\>(.+)\</" => function($m) {
        return '> ' . c(($m[1]), 'yellow') . ' <';
      },
      "/\s+(\w+)=(\"[^\"]+\")/" => function($m) {
        return ' ' . c($m[1], 'red') . '=' . c($m[2], 'green');
      },
      "/\<(\/?)(\w+)([^>]*)(\/?>)/" => function($m) {
        return '<'.$m[1].c($m[2], 'teal').$m[3].$m[4];
      }
    );

    foreach ($colorizer as $rx => $callback) $xml = preg_replace_callback($rx, $callback, $xml);
  }
  
  echo $xml . "\n";
} else {
  echo b('Unknown Format', 'red') . "\n" . str_repeat('-', 80) . "\n";
  echo $code;
}
