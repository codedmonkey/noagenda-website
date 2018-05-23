<?php

namespace App;

class TranscriptParser
{
    public function parse($uri)
    {
        $data = file_get_contents($uri);
        $root = new \SimpleXMLElement($data);

        $output = [
            'lines' => [],
            'invalidLines' => [],
        ];

        $lastTimestamp = 0;

        foreach ($root->body->outline->outline as $outline) {
            $line = (string) $outline['text'];

            if ($line == '') {
                continue;
            }

            preg_match("#^<a target='naplayer' title='click to play' href='http://naplay.it/([^/]+)/([0-9\-]+)'>([^<]+)</a>(.+)$#", $line, $matches);

            if (count($matches) < 5) {
                $output['invalidLines'][] = $line;

                $matches = [null, null, $lastTimestamp + 1, htmlspecialchars($line), ''];
            }

            list(, $showCode, $rawTimestamp, $firstText, $lastText) = $matches;

            $timestamp = $this->parseTimestamp($rawTimestamp);

            $output['lines'][] = [
                'text' => implode('', [$firstText, $lastText]),
                'timestamp' => $timestamp,
                'source' => $uri,
            ];

            // Hold onto last timestamp in case the next line doesn't have one
            $lastTimestamp = $timestamp;
        }

        return $output;
    }

    private function parseTimestamp($raw): int
    {
        if (!strpos($raw, '-')) {
            return (int) $raw;
        }

        list($hours, $minutes, $seconds) = explode('-', $raw);

        $timestamp = $seconds;
        $timestamp += $minutes * 60;
        $timestamp += $hours * 60 * 60;

        return $timestamp;
    }
}