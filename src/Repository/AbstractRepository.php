<?php

namespace App\Repository;

use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\ORM\Query;
use Pagerfanta\Doctrine\ORM\QueryAdapter;
use Pagerfanta\Pagerfanta;

abstract class AbstractRepository extends ServiceEntityRepository
{
    protected ?array $defaultOrderBy = null;
    protected int $itemsPerPage = 50;

    public function findBy(array $criteria = null, array $orderBy = null, $limit = null, $offset = null): array
    {
        $orderBy = array_merge($orderBy ?? [], $this->defaultOrderBy ?? []);

        return parent::findBy($criteria ?? [], $orderBy, $limit, $offset);
    }

    public function findOneBy(array $criteria = null, array $orderBy = null): ?object
    {
        $orderBy = array_merge($orderBy ?? [], $this->defaultOrderBy ?? []);

        return parent::findOneBy($criteria ?? [], $orderBy);
    }

    protected function createPaginator(Query $query, int $page = 1): Pagerfanta
    {
        $paginator = new Pagerfanta(new QueryAdapter($query));

        $paginator->setMaxPerPage($this->itemsPerPage);
        $paginator->setCurrentPage($page);

        return $paginator;
    }
}
