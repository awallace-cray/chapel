#include "insertDefaultInitVariables.h"
#include "symtab.h"
#include "symscope.h"
#include "stmt.h"
#include "expr.h"
#include "type.h"
#include "stringutil.h"


InsertDefaultInitVariables::InsertDefaultInitVariables() {
  whichModules = MODULES_CODEGEN;
}


void InsertDefaultInitVariables::processSymbol(Symbol* sym) {
  static int uid = 1;


  // No type, no default init
  if (VarSymbol* var = dynamic_cast<VarSymbol*>(sym)) {
    if (var->type == dtUnknown && !var->defPoint->exprType) {
      var->noDefaultInit = true;
    }
  }


  if (TypeSymbol *ts = dynamic_cast<TypeSymbol*>(sym)) {
    if (ts->definition->defaultValue) {
      if (UserType* userType = dynamic_cast<UserType*>(ts->definition)) {
        if (userType->defType == dtUnknown &&
            userType->defExpr &&
            userType->defExpr->typeInfo() != dtUnknown) {
          userType->defType = userType->defExpr->typeInfo();
          userType->defExpr = NULL;
          if (!userType->defaultValue) {
            if (userType->defType->defaultValue) {
              userType->defaultValue = userType->defType->defaultValue->copy();
              fixup(userType->symbol->defPoint);
            } else {
              userType->defaultConstructor = userType->defType->defaultConstructor;
            }
          }
        }
      }

      char* temp_name = glomstrings(3, "_init_", sym->name, intstring(uid++));
      Type* temp_type = ts->definition;
      Expr* temp_init = ts->definition->defaultValue->copy();

      Symbol* parent_symbol = sym->defPoint->parentStmt->parentSymbol;
      Symbol* outer_symbol = sym;
      while (dynamic_cast<TypeSymbol*>(parent_symbol)) {
        parent_symbol = parent_symbol->defPoint->parentStmt->parentSymbol;
        outer_symbol = outer_symbol->defPoint->parentStmt->parentSymbol;
      }

      SymScope* saveScope =
        Symboltable::setCurrentScope(outer_symbol->parentScope);
      DefExpr* def = Symboltable::defineSingleVarDef(temp_name,
                                                     temp_type,
                                                     temp_init,
                                                     VAR_NORMAL,
                                                     VAR_VAR);
      Symboltable::setCurrentScope(saveScope);
      if (ModuleSymbol* mod = dynamic_cast<ModuleSymbol*>(parent_symbol)) {
        mod->initFn->body->body->insertAtHead(new ExprStmt(def));
      } else {
        Stmt* insert_point = outer_symbol->defPoint->parentStmt;
        insert_point->insertBefore(new ExprStmt(def));
      }
      VarSymbol* var = dynamic_cast<VarSymbol*>(def->sym);
      ts->definition->defaultValue->replace(new Variable(var));
      var->noDefaultInit = true;
    }
  }
}
