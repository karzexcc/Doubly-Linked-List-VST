(** You should verify a doubly linked list library using VST. You may use
    programs that we provided, or write those programs-to-verify by yourself.
    This library should include the following functions and two extra
    applications:

    struct node;
    struct list;
    struct node * begin(struct list * );
    struct node * end(struct list * );
    struct node * next(struct node * );
    struct node * rbegin(struct list * );
    struct node * rend(struct list * );
    struct node * rnext(struct node * );
    unsigned int get_val(struct node * );
    void insert_before (struct list *, struct node *; unsigned int )
    void insert_after (struct list *, struct node *; unsigned int )

    You may change the definition below if your version is better. *)
    Require Import EV.dlinklist.
    Require Import VST.floyd.proofauto.
    
    Instance CompSpecs : compspecs. make_compspecs prog. Defined.
    Definition Vprog : varspecs. mk_varspecs prog. Defined.
    
    Definition t_struct_node : type := Tstruct _node noattr.
    Definition t_struct_list : type := Tstruct _list noattr.
    
    (** Concrete memory representation of a dlinklist, which does not only include
        value but also include addresses. *)
    
    Fixpoint dlrep (l : list (Z * val)) (head tail prev next : val) : mpred :=
      match l with
      | (x, p) :: l' =>
          EX head' : val,
            !! (p = head) &&
            data_at Tsh t_struct_node (Vint (Int.repr x), (prev, head')) head *
            dlrep l' head' tail head next
      | nil => !! (tail = prev /\ head = next) && emp
      end.
    
    (** Memory representation of a mathematical list. Cursors mean places to
        insert. *)
    Definition list_rep_with_cursor (l : list (Z * val)) (p : val) : mpred :=
      EX (head tail : val),
        data_at Tsh t_struct_list (head, tail) p *
          dlrep l head tail nullval nullval.
    
    Definition list_rep (l : list Z) (p : val) : mpred :=
      EX l0: list (Z * val),
        !! (map fst l0 = l) && list_rep_with_cursor l0 p.
    
    (** Head pointer and tail pointer *)
    Definition head_with_default {A: Type} (l: list A) (default: A): A :=
      match l with
      | a :: _ => a
      | nil => default
      end.
    
    Definition head_ptr (l : list (Z * val)): val :=
      head_with_default (map snd l) nullval.
      
    Definition tail_ptr (l : list (Z * val)): val :=
      head_with_default (rev (map snd l)) nullval.
    
    (* mallocN *)
    Definition mallocN_spec :=
     DECLARE _mallocN
      WITH n: Z
      PRE [tint]
        (* TODO: how to prove 4 <= sizeof(struct list) <= uint_max *)
        (* related lemma(s): body_list_new *)
        PROP ( (*4 <= n <= Int.max_unsigned *) )
        PARAMS (Vint (Int.repr n))
        GLOBALS ()
        SEP ()
      POST [ tptr tvoid ]
        EX v: val,
          PROP (malloc_compatible n v)
          RETURN (v)
          SEP (memory_block Tsh n v).
    
    (* freeN *)
    Definition freeN_spec :=
     DECLARE _freeN
      WITH p : val , n : Z
      PRE [ tptr tvoid , tint ]
        PROP()
        PARAMS (p; Vint (Int.repr n))
        GLOBALS ()
        SEP (memory_block Tsh n p)
      POST [ tvoid ]
        PROP () RETURN () SEP ().
    
    (* list_new *)
    Definition list_new_spec :=
     DECLARE _list_new
      WITH u : unit
      PRE  [  ]
           PROP() PARAMS () GLOBALS () SEP ()
      POST [ tptr t_struct_list ]
        EX v: val,
          PROP ()
          RETURN (v)
          SEP (list_rep nil v).
          
    Definition Gprog_list_new : funspecs := ltac:(with_library prog [list_new_spec; mallocN_spec]).
    
    Check memory_block_zero.
    Check memory_block_isptr.
    Check memory_block_split.
    Check memory_block_data_at_.
    
    Lemma body_list_new: semax_body Vprog Gprog_list_new f_list_new list_new_spec.
    Proof.
      start_function.
      hint.
      
      forward_call ((sizeof(Tstruct _list noattr))%expr).
      (* TODO: if we add the constrains : 4 <= n <= uint_max in mallocN, we
                need to prove `4 <= sizeof(struct list) <= uint_max`. 
                But idk how to do this. *)
      Intros vert.
      hint.
      pose proof memory_block_data_at_ Tsh (Tstruct _list noattr) vert.
      Check malloc_compatible_field_compatible.
      pose proof malloc_compatible_field_compatible. 
      assert_PROP (complete_legal_cosu_type (Tstruct _list noattr) = true).
      entailer!.
      assert_PROP (natural_aligned natural_alignment (Tstruct _list noattr) = true).
      entailer!.
      Print compspecs.
      specialize (H1 _ (Tstruct _list noattr) vert).
      assert (field_compatible (Tstruct _list noattr) [] vert).
      tauto.
      assert (memory_block Tsh (sizeof (Tstruct _list noattr)) vert =
         data_at_ Tsh (Tstruct _list noattr) vert).
      tauto.
      rewrite H5.
      forward.
      forward.
      forward.
      Exists vert.
      entailer!.
      unfold list_rep.
      Exists (@nil (Z * val)).
      entailer!.
      unfold list_rep_with_cursor.
      Exists nullval nullval.
      unfold dlrep.
      entailer!.
    Qed.
    
    
    (* list_free *)
    Definition list_free_spec :=
     DECLARE _list_free
      WITH p : val, l : list Z
      PRE  [ tptr t_struct_list ]
        PROP () 
        PARAMS (p) 
        SEP (list_rep l p)
      POST [ Tvoid ]
        PROP ()
        RETURN ()
        SEP ().
        
    Definition Gprog_list_free : funspecs := ltac:(with_library prog [list_free_spec; freeN_spec]).
    
    Lemma body_list_free: semax_body Vprog Gprog_list_new f_list_free list_free_spec.
    Proof.
      start_function.
      unfold list_rep.
      fold list_rep.
      unfold list_rep_with_cursor.
      Intros l0 head tail.
      forward.
      entailer!.
      
        
    
    (* begin *)
    Definition begin_spec :=
     DECLARE _begin
      WITH p : val, l : list (Z * val)
      PRE  [ tptr t_struct_list ]
        PROP () 
        PARAMS (p)
        GLOBALS ()
        SEP (list_rep_with_cursor l p)
      POST [ tptr t_struct_node ]
        PROP ()
        RETURN (head_ptr l)
        SEP (list_rep_with_cursor l p).
    
    (* end *)
    Definition end_spec :=
     DECLARE _end
      WITH p : val, l : list (Z * val)
      PRE  [ tptr t_struct_list ]
        PROP () 
        PARAMS (p) 
        GLOBALS ()
        SEP (list_rep_with_cursor l p)
      POST [ tptr t_struct_node ]
        PROP ()
        RETURN (nullval)
        SEP (list_rep_with_cursor l p).
    
    (* rbegin *)
    Definition rbegin_spec :=
     DECLARE _rbegin
      WITH p : val, l : list (Z * val)
      PRE  [ tptr t_struct_list ]
        PROP () 
        PARAMS (p) 
        GLOBALS ()
        SEP (list_rep_with_cursor l p)
      POST [ tptr t_struct_node ]
        PROP ()
        RETURN (tail_ptr l)
        SEP (list_rep_with_cursor l p).
    
    (* rend *)
    Definition rend_spec :=
     DECLARE _rend
      WITH p : val, l : list (Z * val)
      PRE  [ tptr t_struct_list ]
        PROP () 
        PARAMS (p) 
        GLOBALS ()
        SEP (list_rep_with_cursor l p)
      POST [ tptr t_struct_node ]
        PROP ()
        RETURN (nullval)
        SEP (list_rep_with_cursor l p).
    
    (* next *)
    Definition next_spec :=
     DECLARE _next
      WITH l1 : list (Z * val), v: Z, p: val, l2 : list (Z * val), x: val
      PRE  [ tptr t_struct_node ]
        PROP () 
        PARAMS (p)
        GLOBALS ()
        SEP (list_rep_with_cursor (l1 ++ [(v, p)] ++ l2) x)
      POST [ tptr t_struct_node ]
        PROP ()
        RETURN (head_ptr l2)
        SEP (list_rep_with_cursor (l1 ++ [(v, p)] ++ l2) x).
    
    (* rnext *)
    Definition rnext_spec :=
     DECLARE _rnext
      WITH l1 : list (Z * val), v: Z, p: val, l2 : list (Z * val), x: val
      PRE  [ tptr t_struct_node ]
        PROP () 
        PARAMS (p)
        GLOBALS ()
        SEP (list_rep_with_cursor (l1 ++ [(v, p)] ++ l2) x)
      POST [ tptr t_struct_node ]
        PROP ()
        RETURN (tail_ptr l1)
        SEP (list_rep_with_cursor (l1 ++ [(v, p)] ++ l2) x).
    
    (* get_val *)
    Definition get_val_spec :=
     DECLARE _get_val
      WITH l1 : list (Z * val), v: Z, p: val, l2 : list (Z * val), x: val
      PRE  [ tptr t_struct_node ]
        PROP () 
        PARAMS (p)
        GLOBALS ()
        SEP (list_rep_with_cursor (l1 ++ [(v, p)] ++ l2) x)
      POST [ tuint ]
        PROP ()
        RETURN (Vint (Int.repr v))
        SEP (list_rep_with_cursor (l1 ++ [(v, p)] ++ l2) x).
    
    (* 2021-04-27 01:16 *)
    