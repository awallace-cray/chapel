#ifndef _pattern_H_
#define _pattern_H_

#include <sys/types.h>
#include "code.h"

class Sym;
class FA;
class Fun;
class AType;
class AVar;
class CreationSet;

#define MAX_ARGS 1000
#define CANNONICAL_MPOSITION ((MPosition*)(intptr_t)(-1))

#define int2Position(_i) ((void*)((intptr_t)-(_i)))
#define Position2int(_p) (-((intptr_t)_p))
#define is_intPosition(_p) (((uint32)Position2int(_p)) < MAX_ARGS)

class MPosition : public gc {
 public:
  Vec<void*> pos;
  MPosition *cp, *up, *next, *down;
  void copy(MPosition &p);
  void set_top(void *p) { pos.v[pos.n-1] = p; cp = 0; }
  void push(int i) { 
    pos.add(int2Position(i));
    if (cp && i == 1)
      cp = cp->down;
    else
      cp = 0;
  }
  void push(void *p) { pos.add(p); cp = 0; }
  void pop() { pos.pop(); if (cp) cp = cp->up; else cp = 0; }
  void inc() { 
    pos.v[pos.n-1] = int2Position(Position2int(pos.v[pos.n-1]) + 1); 
    if (cp) 
      cp = cp->next;
    else
      cp = 0;
  }
  void *last() { return pos.v[pos.n -1]; }
  int is_positional() { 
    for (int i = 0; i < pos.n; i++) 
      if (!is_intPosition(pos.v[i])) return 0; return 1; 
  }
  int last_is_positional() { return is_intPosition(last()); }
  int prefix_to_last(MPosition &p);
  MPosition() : cp(0), up(0), next(0), down(0) {}
  MPosition(MPosition &p);
};
#define forv_MPosition(_p, _v) forv_Vec(MPosition, _p, _v)

inline int 
MPosition::prefix_to_last(MPosition &p) { 
  if (pos.n != p.pos.n + 1) return 0; 
  if (memcmp(pos.v, p.pos.v, p.pos.n * sizeof(void*)))
    return 0;
  return 1;
}

class MPositionHashFuns : public gc {
 public:
  static uint hash(MPosition *x) {
    uint h = 1;
    for (int i = 0; i < x->pos.n; i++)
      h += ((uintptr_t)x->pos.v[i]) * open_hash_multipliers[i];
    if (!h)
      h = 1;
    return h;
  }
  static int equal(MPosition *x, MPosition *y) {
    if (x->pos.n != y->pos.n)
      return 0;
    for (int i = 0; i < x->pos.n; i++)
      if (x->pos.v[i] != y->pos.v[i])
        return 0;
    return 1;
  }
};

class MType : public gc {
 public:
  Map<MPosition *, Vec<Fun *> *> funs;
};

class Patterns : public gc {
 public:
  Vec<Sym *>            types;
  Vec<Sym *>            types_set;
  Vec<MType *>          mtypes; 
};

class Match : public gc {
 public:
  Fun *fun;
  Map<MPosition *, AType *> formal_filters; // formal -> type, positional-only and takes into account all arguments
  unsigned int is_partial : 1;
  // used to verify the match cache
  unsigned int call_is_closure : 1;
  unsigned int call_partial : 3;
  
  Match(Fun *afun) : fun(afun), is_partial(0) { assert(afun); }
  Match(Match &m) : fun(m.fun), is_partial(m.is_partial) { 
    formal_filters.copy(m.formal_filters); 
    call_is_closure = m.call_is_closure;
    call_partial = m.call_partial;
  }
};
#define forv_Match(_p, _v) forv_Vec(Match, _p, _v)

typedef MapElem<MPosition *, AType *> MapMPositionAType;
#define form_MPositionAType(_p, _v) form_Map(MapMPositionAType, _p, _v)
typedef MapElem<MPosition *, MPosition *> MapMPositionMPosition;
#define form_MPositionMPosition(_p, _v) form_Map(MapMPositionMPosition, _p, _v)
typedef MapElem<Sym *, Sym *> MapSymSym;
#define form_SymSym(_p, _v) form_Map(MapSymSym, _p, _v)
typedef MapElem<MPosition *, Sym *> MapMPositionSym;
#define form_MPositionSym(_p, _v) form_Map(MapMPositionSym, _p, _v)


void build_patterns(FA *fa);
void build_patterns(FA *fa, Fun *f);
void build_arg_positions(FA *fa);
int positional_to_named(CreationSet *cs, AVar *av, MPosition &p, MPosition *result_p);
int pattern_match(Vec<AVar *> &args, AVar *send, int is_closure, Partial_kind partial, 
                  Vec<Match *> &matches);
MPosition *cannonicalize_mposition(MPosition &p);
MPosition *build_arg_positions(Fun *f, MPosition *up = 0);

#endif
