# Pacote `bases` — versão revisada

Código de referência. Ajuste o pacote (`com.exemplo.api`) ao do projeto.

## BaseRepository

```java
package com.exemplo.api.bases;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.repository.NoRepositoryBean;

/**
 * Repositório base. JpaSpecificationExecutor habilita
 * findAll(Specification, Pageable) para buscas com XFilter.
 */
@NoRepositoryBean
public interface BaseRepository<E, ID> extends JpaRepository<E, ID>, JpaSpecificationExecutor<E> {
}
```

## ServiceContract

```java
package com.exemplo.api.bases;

import java.util.List;

/**
 * O que o controller enxerga do service: só DTOs, nunca a entidade.
 */
public interface ServiceContract<Request, Dto, ShallowDto, ID> {

    Dto cadastrar(Request request);

    Dto atualizar(ID id, Request request);

    Dto buscarPorId(ID id);

    List<ShallowDto> listar();

    /** Implementado pela BaseService. */
    void remover(ID id);
}
```

## BaseService

```java
package com.exemplo.api.bases;

import com.exemplo.api.exception.NotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.transaction.annotation.Transactional;

/**
 * Base dos services. Não injeta dependências: cada service declara as suas.
 * Os métodos que lidam com a entidade são protected para que nada fora do
 * service consiga ler uma entidade sem passar pelo controle de acesso.
 */
public abstract class BaseService<E, ID> {

    protected final Logger logger = LoggerFactory.getLogger(getClass());

    protected abstract BaseRepository<E, ID> getRepository();

    /** Nome usado nas mensagens de erro, ex.: "Pasto". */
    protected abstract String nomeRecurso();

    /**
     * Garante que o usuário atual pode ver/alterar a entidade.
     * Deve lançar NotFoundException quando não puder (404 não revela que o id existe).
     * Em projetos sem multiusuário, implemente vazio com um comentário dizendo isso.
     */
    protected abstract void verificarAcesso(E entity);

    /** Único caminho para obter uma entidade por id. */
    protected E buscarOuFalhar(ID id) {
        E entity = getRepository().findById(id)
                .orElseThrow(() -> new NotFoundException(nomeRecurso() + " " + id + " não encontrado"));
        verificarAcesso(entity);
        return entity;
    }

    @Transactional
    public void remover(ID id) {
        getRepository().delete(buscarOuFalhar(id));
    }
}
```

## BaseController

```java
package com.exemplo.api.bases;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Endpoints REST padrão de um recurso. A subclasse só define @RequestMapping e getService().
 * Rotas de sub-coleção (ex.: /api/fazendas/{id}/pastos) ficam num controller próprio,
 * porque sobrescrever um método herdado não muda a rota dele.
 */
public abstract class BaseController<Request, Dto, ShallowDto, ID,
        S extends ServiceContract<Request, Dto, ShallowDto, ID>> {

    protected abstract S getService();

    @GetMapping
    public ResponseEntity<List<ShallowDto>> listAll() {
        return ResponseEntity.ok(getService().listar());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Dto> listById(@PathVariable ID id) {
        return ResponseEntity.ok(getService().buscarPorId(id));
    }

    @PostMapping
    public ResponseEntity<Dto> createNew(@RequestBody @Valid Request request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(getService().cadastrar(request));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Dto> update(@PathVariable ID id, @RequestBody @Valid Request request) {
        return ResponseEntity.ok(getService().atualizar(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable ID id) {
        getService().remover(id);
        return ResponseEntity.noContent().build();
    }
}
```

Em projeto legado com `/listAll` e `/new` já consumidos pelo front, troque só as duas
anotações acima.

O Spring MVC resolve os tipos genéricos (`Request`, `ID`) pela subclasse concreta, então
`@RequestBody`, `@Valid` e `@PathVariable` funcionam normalmente nos métodos herdados.

## Exceções e handler

```java
package com.exemplo.api.exception;

public class NotFoundException extends RuntimeException {
    public NotFoundException(String message) { super(message); }
}
```

```java
package com.exemplo.api.exception;

/** Regra de negócio violada (ex.: nome duplicado, estado inválido). */
public class RegraNegocioException extends RuntimeException {
    public RegraNegocioException(String message) { super(message); }
}
```

```java
package com.exemplo.api.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
public class ApiErrorHandler {

    @ExceptionHandler(NotFoundException.class)
    ProblemDetail notFound(NotFoundException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, e.getMessage());
    }

    @ExceptionHandler(RegraNegocioException.class)
    ProblemDetail regra(RegraNegocioException e) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, e.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ProblemDetail validacao(MethodArgumentNotValidException e) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, "Dados inválidos");
        Map<String, String> campos = e.getBindingResult().getFieldErrors().stream()
                .collect(Collectors.toMap(f -> f.getField(),
                        f -> String.valueOf(f.getDefaultMessage()), (a, b) -> a));
        pd.setProperty("campos", campos);
        return pd;
    }
}
```

## Extensão opcional: busca paginada

Para recursos com filtro, o service implementa também `PesquisaContract` e o controller
expõe `/search`.

```java
public interface PesquisaContract<Filter, ShallowDto> {
    Page<ShallowDto> pesquisar(Filter filter, Pageable pageable);
}
```

```java
// no XController
@GetMapping("/search")
public ResponseEntity<Page<XShallowDto>> search(XFilter filter, Pageable pageable) {
    return ResponseEntity.ok(service.pesquisar(filter, pageable));
}
```

```java
// no XService — o escopo do usuário entra na Specification
@Transactional(readOnly = true)
public Page<XShallowDto> pesquisar(XFilter f, Pageable pageable) {
    Specification<X> spec = XSpecs.doEscopo(contexto.fazendaIdsDoUsuarioAtual())
            .and(XSpecs.nomeContem(f.nome()));
    return repository.findAll(spec, pageable).map(mapper::toShallow);
}
```
