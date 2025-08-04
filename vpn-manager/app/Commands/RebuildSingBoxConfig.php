<?php

namespace App\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class RebuildSingBoxConfig extends Command
{
    protected $signature = 'sing-box:rebuild {--output= : Output file path} {--apply : Apply the configuration} {--template=config}';

    protected $description = 'Rebuild Sing-Box configuration file';

    public function handle()
    {
        $template = $this->option('template');
        if ($template === 'config') {
            $template = config('sing-box.template');
        } else {
            $template = require_once $template;
        }

        $template = $this->buildConfig($template);

        $template = json_encode($template, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        if ($outputPath = $this->option('output')) {
            file_put_contents($outputPath, $template);
        } else {
            $this->output->writeln($template);
        }

        if ($this->option('apply')) {
            exec('systemctl reload sing-box', $output, $returnVar);
            if ($returnVar !== 0) {
                $this->error('Failed to apply configuration: '.implode("\n", $output));

                return 1;
            }
            $this->info('Configuration applied successfully.');
        }
    }

    protected function buildConfig(array $template): array
    {
        if (! isset($template['log'])) {
            $template['log'] = ['level' => 'debug'];
        }
        if (Arr::get($template, 'log.level') === null) {
            Arr::set($template, 'log.level', 'debug');
        }
        if (Arr::get($template, 'dns.independent_cache') === null) {
            Arr::set($template, 'dns.independent_cache', true);
        }
        if (Arr::get($template, 'dns.strategy') === null) {
            Arr::set($template, 'dns.strategy', 'ipv4_only');
        }
        Arr::set($template, 'dns.servers', $this->buildDNSServers($template));
        Arr::set($template, 'dns.rules', $this->buildDNSRules($template));
        Arr::set($template, 'outbounds', $this->buildOutbounds($template));
        Arr::set($template, 'route.rules', $this->buildRoutingRules($template));

        return $template;
    }

    protected function buildDNSServers(array $template): array
    {
        $servers = [];
        $tags = [];
        foreach ($template['outbounds'] as $outbound) {
            foreach (Arr::wrap($outbound['tag']) as $tag) {
                if (! in_array($tag, $tags)) {
                    $tags[] = $tag;
                }
            }
        }
        $tags = Arr::reject($tags, fn ($tag) => $tag === $template['route']['final']);
        $tags = Arr::prepend($tags, $template['route']['final']);

        foreach ($tags as $tag) {
            $address = match ($tag) {
                'direct' => 'local',
                default => 'tcp://8.8.8.8',
            };

            $servers[] = [
                'tag' => 'dns-'.$tag,
                'address' => $address,
                'detour' => $tag,
            ];
        }
        $servers[] = ['tag' => 'dns-block', 'address' => 'rcode://success'];

        return $servers;
    }

    protected function buildDNSRules(array $template): array
    {
        $rules = Arr::get($template, 'dns.rules', []);
        for ($x = 0; $x < count($rules); $x++) {
            if (isset($rules[$x]['simple_rules']) and $rules[$x]['simple_rules'] === 'auto') {
                $simpleRules = array_filter(Arr::get($template, 'route.rules'), fn ($r) => isset($r['simple_rules']));
                $simpleRules = array_column($simpleRules, 'simple_rules');
                $simpleRules = array_merge(...$simpleRules);
                $simpleRules = $this->convertSimpleRulesToDNSRules($simpleRules);

                array_splice($rules, $x, 1, $simpleRules);
                $x += count($simpleRules);
            }
        }

        $rules[] = [
            'outbound' => ['any'],
            'server' => 'dns-'.$template['route']['final'],
        ];

        return $rules;
    }

    protected function convertSimpleRulesToDNSRules(array $rules): array
    {
        $rules = array_filter($rules, fn (string $k) => Str::startsWith($k, ['domain_suffix', 'geosite']), ARRAY_FILTER_USE_KEY);
        $actionGroups = collect($rules)
            ->groupBy([fn ($v) => $v, fn ($v, $key) => Str::before($key, ':')], true)
            ->map(function ($actionGroup) {
                return $actionGroup->map(function ($ruleGroup, $rule) {
                    return $ruleGroup->keys()->map(fn ($item) => substr($item, strlen($rule) + 1));
                })->sortBy(fn ($v, $key) => match ($key) {
                    'ip_cidr' => 0,
                    'geoip' => 1,
                    'domain_suffix' => 2,
                    'geosite' => 3,
                    default => 4
                });
            })
            ->sortBy(fn ($v, $key) => match ($key) {
                'block' => 0,
                'direct' => 1,
                default => 2,
            })
            ->toArray();
        $rules = [];
        foreach ($actionGroups as $action => $conditions) {
            foreach ($conditions as $condition => $items) {
                $conditionKey = $condition;
                if ($condition === 'geoip' or $condition === 'geosite') {
                    $conditionKey = 'rule_set';
                    $items = array_map(fn (string $item) => $condition.':'.$item, $items);
                }
                $rules[] = [
                    $conditionKey => $items,
                    'server' => 'dns-'.$action,
                ];
            }

        }

        return $rules;
    }

    protected function convertSimpleRulesToRoutingRules(array $rules): array
    {
        $actionGroups = collect($rules)
            ->groupBy([fn ($v) => $v, fn ($v, $key) => Str::before($key, ':')], true)
            ->map(function ($actionGroup) {
                return $actionGroup->map(function ($ruleGroup, $rule) {
                    return $ruleGroup->keys()->map(fn ($item) => substr($item, strlen($rule) + 1));
                })->sortBy(fn ($v, $key) => match ($key) {
                    'ip_cidr' => 0,
                    'geoip' => 1,
                    'domain_suffix' => 2,
                    'geosite' => 3,
                    default => 4
                });
            })
            ->sortBy(fn ($v, $key) => match ($key) {
                'block' => 0,
                'direct' => 1,
                default => 2,
            })
            ->toArray();
        $rules = [];
        foreach ($actionGroups as $action => $conditions) {
            foreach ($conditions as $condition => $items) {
                $conditionKey = $condition;
                $actionKey = 'outbound';
                if ($condition === 'geoip' or $condition === 'geosite') {
                    $conditionKey = 'rule_set';
                    $items = array_map(fn (string $item) => $condition.':'.$item, $items);
                }
                if ($action === 'block') {
                    $actionKey = 'action';
                    $action = 'reject';
                }
                $rules[] = [
                    $conditionKey => $items,
                    $actionKey => $action,
                ];
            }
        }

        return $rules;
    }

    protected function buildOutbounds(array $template): array
    {
        $selectors = [];
        $tags = [];
        foreach ($template['outbounds'] as &$outbound) {
            if (! isset($outbound['tag'])) {
                $outbound['tag'] = [];
            }
            $outbound['tag'] = Arr::wrap($outbound['tag']);
            if (! count($outbound['tag'])) {
                $outbound['tag'][0] = Str::uuid()->__toString();
            }
            foreach ($outbound['tag'] as $tag) {
                if (! isset($tags[$tag])) {
                    $tags[$tag] = 1;
                } else {
                    $tags[$tag]++;
                }
            }
        }
        foreach ($template['outbounds'] as &$outbound) {
            $primaryTag = null;
            foreach ($outbound['tag'] as $tag) {
                if ($tags[$tag] === 1) {
                    $primaryTag = $tag;
                }
            }
            if (! $primaryTag) {
                throw new \Exception('No primary tag found for outbound: '.json_encode($outbound));
            }
            foreach ($outbound['tag'] as $tag) {
                if ($tag !== $primaryTag) {
                    if (! isset($selectors[$tag])) {
                        $selectors[$tag] = [$primaryTag];
                    } else {
                        $selectors[$tag][] = $primaryTag;
                    }
                }
            }
            $outbound['tag'] = $primaryTag;
        }

        foreach ($selectors as $tag => $outbounds) {
            $template['outbounds'][] = [
                'type' => 'urltest',
                'tag' => $tag,
                'outbounds' => $outbounds,
                'tolerance' => 500,
            ];
        }

        return $template['outbounds'];
    }

    protected function buildRoutingRules(array $template): array
    {
        $rules = Arr::get($template, 'route.rules', []);
        for ($x = 0; $x < count($rules); $x++) {
            if (isset($rules[$x]['simple_rules'])) {
                $simpleRules = $this->convertSimpleRulesToRoutingRules($rules[$x]['simple_rules']);

                array_splice($rules, $x, 1, $simpleRules);
                $x += count($simpleRules);
            }
        }

        return $rules;
    }

    protected function sortSimpleRules(array $rules): array
    {
        $priority = [
            'ip_cidr',
            'geoip',
            'domain',
            'domain_regex',
            'domain_suffix',
            'geosite',
        ];
        usort($rules, function (string $a, string $b) use ($priority): int {
            $a = Str::before($a, ':');
            $b = Str::before($b, ':');

            $a = array_search($a, $priority);
            $b = array_search($b, $priority);

            return $a - $b;
        });
        uasort($rules, function ($a, $b) {
            $a = intval($a === 'block');
            $b = intval($b === 'block');

            return $b - $a;
        });

        return $rules;
    }
}
