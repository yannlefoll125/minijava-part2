open AST
open Type
open TypeErrors


(* Check if parent's methods are explicitely declared in subclass. If not, add them *)
(* Returns "updated" list of subclass' methods *)
let rec check_meth_presence parentm meth=
	match meth with
	| [] -> []
	| m::t-> if not (parentm.mname=m.mname) then (parentm::(check_meth_presence parentm t))
			else m::(check_meth_presence parentm t)

(* "Remove" method from parent's (override) if declared in subclass *)
let rec new_meth_list parent_meth meth=
	match parent_meth with
	| [] -> []
	| m:: t -> check_meth_presence m meth

let rec get_parent_meth c env =
	match env with
	|[] -> []
	| (id, c1) :: t -> if id = c.cparent.tid then c1.cmethods
					else get_parent_meth c t

(* 1st pass.2 : detection of method declarations, add them to env and check heritage*)
(* Returns the "updated" env *)
let rec meth_env_c classname env=
	match env with
	| [] -> []
	| (id, c):: t when id=classname -> (let c2 =	{cparent=c.cparent; 
													cattributes=c.cattributes; 
													cinits=c.cinits;
													cconsts=c.cconsts;
													cmethods=(new_meth_list (get_parent_meth c env) c.cmethods);
													ctypes=c.ctypes;
													cloc=c.cloc} 
										in (id,c2)::(meth_env_c classname t))
	| (id, c):: t -> (id,c)::(meth_env_c classname t)

let rec meth_env env= match env with
	| [] -> []
	| (id, c):: t -> (meth_env_c id env)@(meth_env t)

(* Find if the class was already declared (ie added to env) *)
let rec class_exists classname env =
		match env with
		[] -> false
		| (id, c):: t -> if id=classname then true (* (id, c) *)
							else class_exists classname t

let rec cparent_in_cenv c cenv=
	match cenv with
	|[] -> false
	| (id, c1) :: t -> if id = c.cparent.tid then true
					else cparent_in_cenv c t


(* Check heritage *)
let rec check_cparent cenv=
	match cenv with
	| [] -> true
	| (id, c):: t -> if ((not (c.cparent.tid="Object")) && (not (cparent_in_cenv c cenv) )) then (raise (Parent_class_unknown(c.cparent.tid)))
						else check_cparent t 

(* 1st pass.1 : detection of class declarations, add them to env *)
let type_type_info info id env = 
	match info with
	| Class c ->  if not (class_exists id env) then (id, c) :: env
					else raise (Class_already_declared(id))
	| Inter -> env (* We don't consider interfaces here *)

(* 2nd pass : check if attribute in env *)
let rec attr_exists attr attr_env =
		match attr_env with
		[] -> false
		| a:: t -> if a=attr then true
							else attr_exists attr t

let isPrimitiveType a = 
  match (Type.stringOf a.atype) with
  | "boolean"
  | "char"   
  | "byte"   
  | "short"  
  | "int"    
  | "long"   
  | "float"  
  | "double" 
  | "String"
      -> true
  | _ -> false


(* check if the attribute was already declared *)
let rec attr_decl attr_list attr_name=
		match attr_list with
		[] -> false
		| a:: t -> if a.aname=attr_name then true (* (id, c) *)
					else attr_decl t attr_name


let rec type_attributes attr_list env =
  match attr_list with
    | [] -> []
    | a::t ->   
    			(* check if primitive type (isPrimitiveType defined in Type.ml) *)
			    if not (isPrimitiveType a)
			    then raise (Unknown_type(Type.stringOf a.atype));
			    (* check if the attribute was already declared *)
			    if (attr_decl attr_list a.aname) then raise (Attribute_already_declared(a.aname))
				else a::(type_attributes t env)

(* 2nd pass : type class body *)
let rec type_class_body env =
  match env with
    | [] -> []
    | (id, c):: t -> let nenv = type_attributes c.cattributes env in nenv@(type_class_body t)

      
let type_asttype exp env = type_type_info exp.info exp.id env

let rec class_env type_list env=
	match type_list with
	| [] -> []
	| h::t -> let nenv2= (let nenv= type_asttype h env 
							in nenv @ class_env t nenv) 
				in (meth_env nenv2)

let typing exp env = 
	let classenv = class_env exp.type_list env in 
		if (check_cparent classenv) then (print_endline "heritage ok");
		type_class_body classenv


