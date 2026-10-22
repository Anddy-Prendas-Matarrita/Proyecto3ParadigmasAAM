% ============================================
% consultas.pl - consultas sugeridas (generado automaticamente)
% Uso: swipl consultas.pl   y luego   ?- ejecutar_todas.
% ============================================

:- ensure_loaded('conocimiento.pl').

% consulta(Numero, Descripcion, ObjetivoComoTexto)
consulta(1, 'Todas las personas', 'persona(X)').
consulta(2, 'Todos los cursos', 'curso(X)').
consulta(3, 'Todos los docentes', 'docente(X)').
consulta(4, 'Que curso lleva cada persona', 'lleva(P, C)').
consulta(5, 'Que curso imparte cada docente', 'imparte(D, C)').
consulta(6, 'Companeros de ana', 'companeros(ana, X)').
consulta(7, 'Companeros de luis', 'companeros(luis, X)').
consulta(8, 'Companeros de sofia', 'companeros(sofia, X)').
consulta(9, 'Docente del curso paradigmas', 'curso_con_docente(paradigmas, D)').
consulta(10, 'Docente del curso bases_de_datos', 'curso_con_docente(bases_de_datos, D)').
consulta(11, 'Docentes de ana', 'docente_de(ana, D)').
consulta(12, 'Docentes de luis', 'docente_de(luis, D)').
consulta(13, 'Docentes de sofia', 'docente_de(sofia, D)').
consulta(14, 'Cursos pendientes de ana', 'pendiente(ana, C)').
consulta(15, 'Cursos pendientes de luis', 'pendiente(luis, C)').
consulta(16, 'Cursos pendientes de sofia', 'pendiente(sofia, C)').
consulta(17, 'Carga de maria', 'carga_docente(maria, N)').

% Ejecuta todas las consultas y muestra sus resultados.
ejecutar_todas :-
    forall(consulta(N, Desc, Texto),
           ( format('~w. ~w~n', [N, Desc]),
             term_to_atom(Goal, Texto),
             findall(Goal, Goal, Rs),
             (   Rs == []
             ->  format('   (sin resultados)~n')
             ;   forall(member(R, Rs), format('   ~q~n', [R]))
             ) )).
