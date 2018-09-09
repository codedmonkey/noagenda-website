<?php
/*
 * This file is part of the Onlinq library.
 *
 * (c) Onlinq <info@onlinq.nl>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

namespace App\Updates;

use Psr\Container\ContainerInterface;
use Symfony\Component\DependencyInjection\ServiceLocator;
use Symfony\Component\DependencyInjection\ServiceSubscriberInterface;
use Symfony\Component\Routing\Generator\UrlGeneratorInterface;
use Symfony\Component\Routing\RouterInterface;

abstract class AbstractUpdater implements ServiceSubscriberInterface
{
    public static function getSubscribedServices()
    {
        return [
            'mailer' => \Swift_Mailer::class,
            'router' => RouterInterface::class,
            'twig' => \Twig_Environment::class,
        ];
    }

    /**
     * @var ServiceLocator
     */
    protected $locator;

    public function __construct(ContainerInterface $locator)
    {
        $this->locator = $locator;
    }

    public function getAuthorEmail(): string
    {
        return $_SERVER['MAILER_FROM'] ?? 'notifications@noagendaexperience.com';
    }

    public function getAuthorName(): string
    {
        return $_SERVER['MAILER_FROM_AUTHOR'] ?? 'No Agenda Experience';
    }

    public function generateUrl(string $route, array $parameters = []): string
    {
        $router = $this->locator->get('router');

        return $router->generate($route, $parameters, UrlGeneratorInterface::ABSOLUTE_URL);
    }

    public function renderTemplate(string $template, array $variables = []): string
    {
        $twig = $this->locator->get('twig');

        return $twig->render($template, $variables);
    }

    public function sendMessage(\Swift_Message $message): bool
    {
        $mailer = $this->locator->get('mailer');

        return (bool) $mailer->send($message);
    }
}