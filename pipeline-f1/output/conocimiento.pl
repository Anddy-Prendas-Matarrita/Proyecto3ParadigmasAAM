% ============================================
% conocimiento.pl - generado automaticamente
% ============================================

:- discontiguous persona/1, curso/1, docente/1.
:- dynamic persona/1, curso/1, docente/1.
:- dynamic lleva/2, imparte/2, aprueba/2.

% --- Entidades ---

% linea 2: persona: Ana
persona(ana).

% linea 3: persona: Luis
persona(luis).

% linea 4: persona: Sofía
persona(sofia).

% linea 5: curso: Paradigmas
curso(paradigmas).

% linea 6: curso: Bases de Datos
curso(bases_de_datos).

% linea 7: docente: María
docente(maria).

% --- Relaciones ---

% linea 10: lleva: Ana, Paradigmas
lleva(ana, paradigmas).

% linea 11: lleva: Luis, Paradigmas
lleva(luis, paradigmas).

% linea 12: lleva: Sofía, Bases de Datos
lleva(sofia, bases_de_datos).

% linea 13: imparte: María, Paradigmas
imparte(maria, paradigmas).

% linea 14: imparte: María, Bases de Datos
imparte(maria, bases_de_datos).

% linea 15: aprueba: Ana, Paradigmas
aprueba(ana, paradigmas).

% --- Reglas ---

% companeros(X, Y): X e Y llevan al menos un curso en comun.
companeros(X, Y) :-
    lleva(X, Curso),
    lleva(Y, Curso),
    X \= Y.

% curso_con_docente(Curso, Docente): docente que imparte el curso.
curso_con_docente(Curso, Docente) :-
    curso(Curso),
    imparte(Docente, Curso).

% docente_de(Persona, Docente): el docente imparte un curso que lleva la persona.
docente_de(Persona, Docente) :-
    lleva(Persona, Curso),
    imparte(Docente, Curso).

% pendiente(Persona, Curso): la persona lleva el curso y no lo ha aprobado.
pendiente(Persona, Curso) :-
    lleva(Persona, Curso),
    \+ aprueba(Persona, Curso).

% carga_docente(Docente, N): cantidad de cursos que imparte el docente.
carga_docente(Docente, N) :-
    docente(Docente),
    findall(C, imparte(Docente, C), Cs),
    length(Cs, N).

