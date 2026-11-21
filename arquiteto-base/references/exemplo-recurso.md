# Exemplo de ponta a ponta: recurso `Pasto`

Recurso com escopo multiusuário: cada pasto pertence a uma fazenda, e o usuário só enxerga
as fazendas às quais tem acesso (`ContextoSeguranca`). Em um projeto de usuário único,
`verificarAcesso` fica vazio e `listar` usa `findAll()`.

## DTOs

```java
public record PastoRequest(
        @NotBlank String nome,
        @Positive Double areaHa,
        @Positive Double perimetroM,
        String cor,
        String coordenadas,
        @NotBlank String fazendaId) {
}

public record PastoDto(
        String id, String nome, Double areaHa, Double perimetroM,
        String cor, String coordenadas, String fazendaId, String createdAt) {
}

public record PastoShallowDto(String id, String nome, Double areaHa, String cor, String fazendaId) {
}
```

## Repository

```java
public interface PastoRepository extends BaseRepository<Pasto, String> {

    List<Pasto> findAllByFazendaIdIn(List<String> fazendaIds);
}
```

## Mapper

```java
@Component
public class PastoMapper {

    public Pasto toEntity(PastoRequest r) {
        Pasto p = new Pasto();
        p.setId(UUID.randomUUID().toString());
        p.setCreatedAt(LocalDateTime.now().toString());
        copiar(r, p);
        return p;
    }

    public void copiar(PastoRequest r, Pasto p) {
        p.setNome(r.nome());
        p.setAreaHa(r.areaHa());
        p.setPerimetroM(r.perimetroM());
        p.setCor(r.cor());
        p.setCoordenadas(r.coordenadas());
        p.setFazendaId(r.fazendaId());
    }

    public PastoDto toDto(Pasto p) {
        return new PastoDto(p.getId(), p.getNome(), p.getAreaHa(), p.getPerimetroM(),
                p.getCor(), p.getCoordenadas(), p.getFazendaId(), p.getCreatedAt());
    }

    public PastoShallowDto toShallow(Pasto p) {
        return new PastoShallowDto(p.getId(), p.getNome(), p.getAreaHa(), p.getCor(), p.getFazendaId());
    }
}
```

## Service

```java
@Service
@RequiredArgsConstructor
public class PastoService extends BaseService<Pasto, String>
        implements ServiceContract<PastoRequest, PastoDto, PastoShallowDto, String> {

    private final PastoRepository repository;
    private final PastoMapper mapper;
    private final ContextoSeguranca contexto;

    @Override
    protected BaseRepository<Pasto, String> getRepository() {
        return repository;
    }

    @Override
    protected void verificarAcesso(Pasto pasto) {
        verificarFazenda(pasto.getFazendaId());
    }

    @Override
    @Transactional
    public PastoDto cadastrar(PastoRequest request) {
        verificarFazenda(request.fazendaId());          // o "pai" também precisa ser do usuário
        return mapper.toDto(repository.save(mapper.toEntity(request)));
    }

    @Override
    @Transactional
    public PastoDto atualizar(String id, PastoRequest request) {
        Pasto pasto = buscarOuFalhar(id);
        verificarFazenda(request.fazendaId());          // impede mover para fazenda alheia
        mapper.copiar(request, pasto);
        return mapper.toDto(repository.save(pasto));
    }

    @Override
    @Transactional(readOnly = true)
    public PastoDto buscarPorId(String id) {
        return mapper.toDto(buscarOuFalhar(id));
    }

    @Override
    @Transactional(readOnly = true)
    public List<PastoShallowDto> listar() {
        List<String> fazendas = contexto.fazendaIdsDoUsuarioAtual(); // null = admin
        List<Pasto> pastos = fazendas == null ? repository.findAll() : repository.findAllByFazendaIdIn(fazendas);
        return pastos.stream().map(mapper::toShallow).toList();
    }

    private void verificarFazenda(String fazendaId) {
        List<String> fazendas = contexto.fazendaIdsDoUsuarioAtual();
        if (fazendas != null && !fazendas.contains(fazendaId)) {
            throw new NotFoundException("Registro não encontrado");
        }
    }
}
```

## Controller

```java
@RestController
@RequestMapping("/api/pastos")
@RequiredArgsConstructor
public class PastoController
        extends BaseController<PastoRequest, PastoDto, PastoShallowDto, String, PastoService> {

    private final PastoService service;

    @Override
    protected PastoService getService() {
        return service;
    }
}
```

## Testes mínimos

```java
@ExtendWith(MockitoExtension.class)
class PastoServiceTest {

    @Mock PastoRepository repository;
    @Mock ContextoSeguranca contexto;
    @Spy PastoMapper mapper = new PastoMapper();
    @InjectMocks PastoService service;

    @Test
    void buscarPastoDeOutraFazendaDa404() {
        Pasto alheio = new Pasto();
        alheio.setFazendaId("outra");
        when(repository.findById("p1")).thenReturn(Optional.of(alheio));
        when(contexto.fazendaIdsDoUsuarioAtual()).thenReturn(List.of("minha"));

        assertThrows(NotFoundException.class, () -> service.buscarPorId("p1"));
    }
}
```

No `@WebMvcTest` do controller, confira: `POST /new` → 201 com corpo `PastoDto`;
corpo inválido → 400 com `campos`; `DELETE /{id}` → 204; id inexistente → 404.
