open Prelude

(* Dark *)
module B = BlankOr
module P = Pointer
module TL = Toplevel
module TD = TLIDDict
module E = FluidExpression

let pass : testResult = Ok ()

let fail ?(f : 'a -> string = Js.String.make) (v : 'a) : testResult =
  Error (f v)


let testIntOption ~(errMsg : string) ~(expected : int) ~(actual : int option) :
    testResult =
  match actual with
  | Some a when a = expected ->
      pass
  | Some a ->
      fail
        ( errMsg
        ^ " (Actual: "
        ^ string_of_int a
        ^ ", Expected: "
        ^ string_of_int expected
        ^ ")" )
  | None ->
      fail (errMsg ^ " (Actual: None, Expected: " ^ string_of_int expected ^ ")")


let testInt ~(errMsg : string) ~(expected : int) ~(actual : int) : testResult =
  if actual = expected
  then pass
  else
    fail
      ( errMsg
      ^ " (Actual: "
      ^ string_of_int actual
      ^ ", Expected: "
      ^ string_of_int expected
      ^ ")" )


let showToplevels tls = tls |> TD.values |> show_list ~f:show_toplevel

let onlyTL (m : model) : toplevel option =
  let tls = TL.structural m in
  match StrDict.values tls with [a] -> Some a | _ -> None


let onlyHandler (m : model) : handler option =
  m |> onlyTL |> Option.andThen ~f:TL.asHandler


let onlyDB (m : model) : db option = m |> onlyTL |> Option.andThen ~f:TL.asDB

let onlyExpr (m : model) : E.t option =
  m |> onlyTL |> Option.andThen ~f:TL.getAST |> Option.map ~f:FluidAST.toExpr


let showOption (f : 'e -> string) (o : 'e option) : string =
  match o with Some x -> "Some " ^ f x | None -> "None"


let enter_changes_state (m : model) : testResult =
  match m.cursorState with
  | Omnibox _ ->
      pass
  | _ ->
      fail ~f:show_cursorState m.cursorState


let field_access_closes (m : model) : testResult =
  match m.cursorState with
  | FluidEntering _ ->
    ( match onlyExpr m with
    | Some (EFieldAccess (_, EVariable (_, "request"), "body")) ->
        pass
    | expr ->
        fail ~f:(showOption E.show) expr )
  | _ ->
      fail ~f:show_cursorState m.cursorState


let field_access_pipes (m : model) : testResult =
  match onlyExpr m with
  | Some
      (EPipe
        (_, [EFieldAccess (_, EVariable (_, "request"), "body"); EBlank _])) ->
      pass
  | expr ->
      fail ~f:(showOption show_fluidExpr) expr


let tabbing_works (m : model) : testResult =
  match onlyExpr m with
  | Some (EIf (_, EBlank _, EInteger (_, "5"), EBlank _)) ->
      pass
  | e ->
      fail ~f:(showOption show_fluidExpr) e


let autocomplete_highlights_on_partial_match (m : model) : testResult =
  match onlyExpr m with
  | Some (EFnCall (_, "Int::add", _, _)) ->
      pass
  | e ->
      fail ~f:(showOption show_fluidExpr) e


let no_request_global_in_non_http_space (m : model) : testResult =
  (* this might change but this is the answer for now. *)
  match onlyExpr m with
  | Some (EFnCall (_, "Http::badRequest", _, _)) ->
      pass
  | e ->
      fail ~f:(showOption show_fluidExpr) e


let ellen_hello_world_demo (m : model) : testResult =
  let spec =
    onlyTL m
    |> Option.andThen ~f:TL.asHandler
    |> Option.map ~f:(fun x -> x.spec)
  in
  match spec with
  | Some spec ->
    ( match ((spec.space, spec.name), (spec.modifier, onlyExpr m)) with
    | ( (F (_, "HTTP"), F (_, "/hello"))
      , (F (_, "GET"), Some (EString (_, "Hello world!"))) ) ->
        pass
    | other ->
        fail other )
  | other ->
      fail other


let editing_headers (m : model) : testResult =
  let spec =
    onlyTL m
    |> Option.andThen ~f:TL.asHandler
    |> Option.map ~f:(fun x -> x.spec)
  in
  match spec with
  | Some s ->
    ( match (s.space, s.name, s.modifier) with
    | F (_, "HTTP"), F (_, "/myroute"), F (_, "GET") ->
        pass
    | other ->
        fail other )
  | other ->
      fail other


let switching_from_http_space_removes_leading_slash (m : model) : testResult =
  let spec =
    onlyTL m
    |> Option.andThen ~f:TL.asHandler
    |> Option.map ~f:(fun x -> x.spec)
  in
  match spec with
  | Some s ->
    ( match (s.space, s.name, s.modifier) with
    | F (_, newSpace), F (_, "spec_name"), _ when newSpace != "HTTP" ->
        pass
    | other ->
        fail other )
  | other ->
      fail other


let switching_from_http_to_cron_space_removes_leading_slash =
  switching_from_http_space_removes_leading_slash


let switching_from_http_to_repl_space_removes_leading_slash =
  switching_from_http_space_removes_leading_slash


let switching_from_http_space_removes_variable_colons (m : model) : testResult =
  let spec =
    onlyTL m
    |> Option.andThen ~f:TL.asHandler
    |> Option.map ~f:(fun x -> x.spec)
  in
  match spec with
  | Some s ->
    ( match (s.space, s.name, s.modifier) with
    | F (_, newSpace), F (_, "spec_name/variable"), _ when newSpace != "HTTP" ->
        pass
    | other ->
        fail other )
  | other ->
      fail other


let switching_to_http_space_adds_slash (m : model) : testResult =
  let spec =
    onlyTL m
    |> Option.andThen ~f:TL.asHandler
    |> Option.map ~f:(fun x -> x.spec)
  in
  match spec with
  | Some s ->
    ( match (s.space, s.name, s.modifier) with
    | F (_, "HTTP"), F (_, "/spec_name"), _ ->
        pass
    | other ->
        fail other )
  | other ->
      fail other


let switching_from_default_repl_space_removes_name (m : model) : testResult =
  let spec =
    onlyTL m
    |> Option.andThen ~f:TL.asHandler
    |> Option.map ~f:(fun x -> x.spec)
  in
  match spec with
  | Some s ->
    ( match (s.space, s.name, s.modifier) with
    | F (_, newSpace), _, _ when newSpace != "REPL" ->
        pass
    | other ->
        fail other )
  | other ->
      fail other


let tabbing_through_let (m : model) : testResult =
  match onlyExpr m with
  | Some (ELet (_, "myvar", EInteger (_, "5"), EInteger (_, "5"))) ->
      pass
  | e ->
      fail ~f:(showOption show_fluidExpr) e


let rename_db_fields (m : model) : testResult =
  m.dbs
  |> TD.mapValues ~f:(fun {cols; _} ->
         match cols with
         | [ (F (_, "field6"), F (_, "String"))
           ; (F (_, "field2"), F (_, "String"))
           ; (Blank _, Blank _) ] ->
           ( match m.cursorState with
           | Selecting _ ->
               pass
           | _ ->
               fail ~f:show_cursorState m.cursorState )
         | _ ->
             fail ~f:(show_list ~f:show_dbColumn) cols)
  |> Result.combine
  |> Result.map ~f:(fun _ -> ())


let rename_db_type (m : model) : testResult =
  m.dbs
  |> TD.mapValues ~f:(fun {cols; dbTLID; _} ->
         match cols with
         (* this was previously an Int *)
         | [ (F (_, "field1"), F (_, "String"))
           ; (F (_, "field2"), F (_, "Int"))
           ; (Blank _, Blank _) ] ->
           ( match m.cursorState with
           | Selecting (tlid, None) ->
               if tlid = dbTLID
               then pass
               else
                 fail
                   ( show_list ~f:show_dbColumn cols
                   ^ ", "
                   ^ show_cursorState m.cursorState )
           | _ ->
               fail ~f:show_cursorState m.cursorState )
         | _ ->
             fail ~f:(show_list ~f:show_dbColumn) cols)
  |> Result.combine
  |> Result.map ~f:(fun _ -> ())


let feature_flag_works (m : model) : testResult =
  let h = onlyHandler m in
  let ast = h |> Option.map ~f:(fun h -> h.ast |> FluidAST.toExpr) in
  match ast with
  | Some
      (ELet
        ( _
        , "a"
        , EInteger (_, "13")
        , EFeatureFlag
            ( id
            , "myflag"
            , EFnCall
                ( _
                , "Int::greaterThan"
                , [EVariable (_, "a"); EInteger (_, "10")]
                , _ )
            , EString (_, "\"A\"")
            , EString (_, "\"B\"") ) )) ->
      let res =
        h
        |> Option.map ~f:(fun x -> x.hTLID)
        |> Option.andThen ~f:(Analysis.getSelectedTraceID m)
        |> Option.andThen ~f:(Analysis.getLiveValue m id)
      in
      ( match res with
      | Some val_ ->
          if val_ = DStr "B"
          then pass
          else fail (showOption show_fluidExpr ast, val_)
      | _ ->
          fail (showOption show_fluidExpr ast, res) )
  | _ ->
      fail (showOption show_fluidExpr ast, show_cursorState m.cursorState)


let feature_flag_in_function (m : model) : testResult =
  let fun_ = m.userFunctions |> TD.values |> List.head in
  match fun_ with
  | Some f ->
    ( match f.ufAST |> FluidAST.toExpr with
    | EFnCall
        ( _
        , "+"
        , [ EFeatureFlag
              ( _
              , "myflag"
              , EBool (_, true)
              , EInteger (_, "5")
              , EInteger (_, "3") )
          ; EInteger (_, "5") ]
        , NoRail ) ->
        pass
    (* TODO: validate result should evaluate true turning  5 + 5 --> 3 + 5 == 8 *)
    (* let res = Analysis.getLiveValue m f.tlid id in *)
    (* case res of *)
    (*   Just val -> if val.value == "\"8\"" then pass else fail (f.ast, value) *)
    (*   _ -> fail (f.ast, res) *)
    | expr ->
        fail ~f:show_fluidExpr expr )
  | None ->
      fail "Cant find function"


let rename_function (m : model) : testResult =
  match
    m.handlers
    |> TD.values
    |> List.head
    |> Option.map ~f:(fun h -> h.ast |> FluidAST.toExpr)
  with
  | Some (EFnCall (_, "hello", _, _)) ->
      pass
  | Some expr ->
      fail (show_fluidExpr expr)
  | None ->
      fail "no handlers"


let execute_function_works (_ : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let correct_field_livevalue (_ : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let int_add_with_float_error_includes_fnname (_ : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let fluid_execute_function_shows_live_value (_ : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let function_version_renders (_ : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let delete_db_col (m : model) : testResult =
  let db = onlyDB m |> Option.map ~f:(fun d -> d.cols) in
  match db with
  | Some [(Blank _, Blank _)] ->
      pass
  | cols ->
      fail ~f:(showOption (show_list ~f:show_dbColumn)) cols


let cant_delete_locked_col (m : model) : testResult =
  let db =
    m.dbs
    |> fun dbs ->
    if TD.count dbs > 1
    then None
    else TD.values dbs |> List.head |> Option.map ~f:(fun x -> x.cols)
  in
  match db with
  | Some [(F (_, "cantDelete"), F (_, "Int")); (Blank _, Blank _)] ->
      pass
  | cols ->
      fail ~f:(showOption (show_list ~f:show_dbColumn)) cols


let passwords_are_redacted (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let select_route (m : model) : testResult =
  match m.cursorState with
  | Selecting (_, None) ->
      pass
  | _ ->
      fail ~f:show_cursorState m.cursorState


let function_analysis_works (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let jump_to_error (m : model) : testResult =
  let focusedPass =
    match m.currentPage with
    | FocusedHandler (tlid, _, _) when tlid = TLID.fromString "123" ->
        pass
    | _ ->
        fail "function is not focused"
  in
  let expectedCursorPos = 16 in
  let browserCursorPass =
    testIntOption
      ~errMsg:"incorrect browser cursor position"
      ~expected:expectedCursorPos
      ~actual:(Entry.getFluidCaretPos ())
  in
  let cursorPass =
    match m.cursorState with
    | FluidEntering _ ->
        testInt
          ~errMsg:"incorrect cursor position"
          ~expected:expectedCursorPos
          ~actual:m.fluidState.newPos
    | _ ->
        fail "incorrect cursor state"
  in
  Result.combine [focusedPass; browserCursorPass; cursorPass]
  |> Result.map ~f:(fun _ -> ())


let fourohfours_parse (m : model) : testResult =
  match m.f404s with
  | [x] ->
      if x.space = "HTTP"
         && x.path = "/nonexistant"
         && x.modifier = "GET"
         && x.timestamp = "2019-03-15T22:16:40Z"
         && x.traceID = "0623608c-a339-45b3-8233-0eec6120e0df"
      then pass
      else fail ~f:show_fourOhFour x
  | _ ->
      fail ~f:(show_list ~f:show_fourOhFour) m.f404s


let autocomplete_visible_height (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let fn_page_returns_to_lastpos (m : model) : testResult =
  match TL.get m (TLID.fromString "123") with
  | Some tl ->
      let centerPos = Viewport.centerCanvasOn tl in
      if m.canvasProps.offset = centerPos
      then pass
      else fail ~f:show_pos m.canvasProps.offset
  | None ->
      fail "no tl found"


let fn_page_to_handler_pos (_m : model) : testResult = pass

let load_with_unnamed_function (_m : model) : testResult = pass

let create_new_function_from_autocomplete (m : model) : testResult =
  let module TD = TLIDDict in
  match (TD.toList m.userFunctions, TD.toList m.handlers) with
  | ( [ ( _
        , { ufAST
          ; ufMetadata =
              { ufmName = F (_, "myFunctionName")
              ; ufmParameters = []
              ; ufmDescription = ""
              ; ufmReturnTipe = F (_, TAny)
              ; ufmInfix = false }
          ; _ } ) ]
    , [(_, {ast; _})] ) ->
    ( match (FluidAST.toExpr ufAST, FluidAST.toExpr ast) with
    | EBlank _, EFnCall (_, "myFunctionName", [], _) ->
        pass
    | _ ->
        fail "bad asts" )
  | fns, hs ->
      fail (fns, hs)


let extract_from_function (m : model) : testResult =
  match m.cursorState with
  | FluidEntering tlid when tlid = TLID.fromString "123" ->
      if TD.count m.userFunctions = 2 then pass else fail m.userFunctions
  | _ ->
      fail (show_cursorState m.cursorState)


let fluidGetSelectionRange (s : fluidState) : (int * int) option =
  match s.selectionStart with
  | Some beginIdx ->
      Some (beginIdx, s.newPos)
  | None ->
      None


let fluid_doubleclick_selects_token (m : model) : testResult =
  match fluidGetSelectionRange m.fluidState with
  | Some (34, 40) ->
      pass
  | Some (a, b) ->
      fail
        ( "incorrect selection range for token: ("
        ^ string_of_int a
        ^ ", "
        ^ string_of_int b
        ^ ")" )
  | None ->
      fail "no selection range"


let fluid_doubleclick_with_alt_selects_expression (m : model) : testResult =
  match fluidGetSelectionRange m.fluidState with
  | Some (34, 965) ->
      pass
  | Some (a, b) ->
      fail
        ( "incorrect selection range for expression: ("
        ^ string_of_int a
        ^ ", "
        ^ string_of_int b
        ^ ")" )
  | None ->
      fail "no selection range"


let fluid_doubleclick_selects_word_in_string (m : model) : testResult =
  match fluidGetSelectionRange m.fluidState with
  | Some (13, 22) ->
      pass
  | Some (a, b) ->
      fail
        ( "incorrect selection range for token: ("
        ^ string_of_int a
        ^ ", "
        ^ string_of_int b
        ^ ")" )
  | None ->
      fail "no selection range"


let fluid_doubleclick_selects_entire_fnname (m : model) : testResult =
  match fluidGetSelectionRange m.fluidState with
  | Some (0, 14) ->
      pass
  | Some (a, b) ->
      fail
        ( "incorrect selection range for token: ("
        ^ string_of_int a
        ^ ", "
        ^ string_of_int b
        ^ ")" )
  | None ->
      fail "no selection range"


let fluid_single_click_on_token_in_deselected_handler_focuses (m : model) :
    testResult =
  match m.currentPage with
  | FocusedHandler (tlid, _, _) when tlid = TLID.fromString "598813411" ->
      pass
  | _ ->
      fail "handler is not focused"


let fluid_click_2x_on_token_places_cursor (m : model) : testResult =
  let focusedPass =
    match m.currentPage with
    | FocusedHandler (tlid, _, _) when tlid = TLID.fromString "1835485706" ->
        pass
    | _ ->
        fail "handler is not focused"
  in
  let expectedCursorPos = 6 in
  let browserCursorPass =
    testIntOption
      ~errMsg:"incorrect browser cursor position"
      ~expected:expectedCursorPos
      ~actual:(Entry.getFluidCaretPos ())
  in
  let cursorPass =
    match m.cursorState with
    | FluidEntering _ ->
        testInt
          ~errMsg:"incorrect cursor position"
          ~expected:expectedCursorPos
          ~actual:m.fluidState.newPos
    | _ ->
        fail "incorrect cursor state"
  in
  Result.combine [focusedPass; browserCursorPass; cursorPass]
  |> Result.map ~f:(fun _ -> ())


let fluid_click_2x_in_function_places_cursor (m : model) : testResult =
  let focusedPass =
    match m.currentPage with
    | FocusedFn (tlid, _) when tlid = TLID.fromString "1352039682" ->
        pass
    | _ ->
        fail "function is not focused"
  in
  let expectedCursorPos = 17 in
  let browserCursorPass =
    testIntOption
      ~errMsg:"incorrect browser cursor position"
      ~expected:expectedCursorPos
      ~actual:(Entry.getFluidCaretPos ())
  in
  let cursorPass =
    match m.cursorState with
    | FluidEntering _ ->
        testInt
          ~errMsg:"incorrect cursor position"
          ~expected:expectedCursorPos
          ~actual:m.fluidState.newPos
    | _ ->
        fail "incorrect cursor state"
  in
  Result.combine [focusedPass; browserCursorPass; cursorPass]
  |> Result.map ~f:(fun _ -> ())


let fluid_shift_right_selects_chars_in_front (m : model) : testResult =
  match fluidGetSelectionRange m.fluidState with
  | Some (262, 341) ->
      pass
  | Some (a, b) ->
      fail
        ( "incorrect selection range for token: ("
        ^ string_of_int a
        ^ ", "
        ^ string_of_int b
        ^ ")" )
  | None ->
      fail "no selection range"


let fluid_shift_left_selects_chars_at_back (m : model) : testResult =
  match fluidGetSelectionRange m.fluidState with
  | Some (339, 261) ->
      pass
  | Some (a, b) ->
      fail
        ( "incorrect selection range for expression: ("
        ^ string_of_int a
        ^ ", "
        ^ string_of_int b
        ^ ")" )
  | None ->
      fail "no selection range"


let fluid_undo_redo_happen_exactly_once (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let fluid_ctrl_left_on_string (_m : model) : testResult =
  let expectedPos = 7 in
  testIntOption
    ~errMsg:
      ( "incorrect browser cursor position, expected: "
      ^ (expectedPos |> string_of_int)
      ^ ", current: "
      ^ ( Entry.getFluidCaretPos ()
        |> Option.withDefault ~default:0
        |> string_of_int ) )
    ~expected:expectedPos
    ~actual:(Entry.getFluidCaretPos ())


let fluid_ctrl_right_on_string (_m : model) : testResult =
  let expectedPos = 14 in
  testIntOption
    ~errMsg:
      ( "incorrect browser cursor position, expected: "
      ^ (expectedPos |> string_of_int)
      ^ ", current: "
      ^ ( Entry.getFluidCaretPos ()
        |> Option.withDefault ~default:0
        |> string_of_int ) )
    ~expected:expectedPos
    ~actual:(Entry.getFluidCaretPos ())


let fluid_ctrl_left_on_empty_match (_m : model) : testResult =
  let expectedPos = 6 in
  testIntOption
    ~errMsg:
      ( "incorrect browser cursor position, expected: "
      ^ (expectedPos |> string_of_int)
      ^ ", current: "
      ^ ( Entry.getFluidCaretPos ()
        |> Option.withDefault ~default:0
        |> string_of_int ) )
    ~expected:expectedPos
    ~actual:(Entry.getFluidCaretPos ())


let varnames_are_incomplete (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let center_toplevel (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let max_callstack_bug (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let sidebar_opens_function (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let empty_fn_never_called_result (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let empty_fn_been_called_result (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let sha256hmac_for_aws (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let fluid_fn_pg_change (_m : model) : testResult =
  (* The test logic is in tests.js *)
  pass


let fluid_creating_an_http_handler_focuses_the_verb (_m : model) : testResult =
  pass


let fluid_tabbing_from_an_http_handler_spec_to_ast (_m : model) : testResult =
  pass


let fluid_tabbing_from_handler_spec_past_ast_back_to_verb (_m : model) :
    testResult =
  pass


let fluid_shift_tabbing_from_handler_ast_back_to_route (_m : model) : testResult
    =
  pass


let fluid_test_copy_request_as_curl (m : model) : testResult =
  (* test logic is here b/c testcafe can't get clipboard data *)
  let curl =
    CurlCommand.curlFromHttpClientCall
      m
      (TLID.fromString "91390945")
      (ID "753586717")
      "HttpClient::post"
  in
  let expected = "curl -H 'h:3' -d 'some body' -X post 'https://foo.com?q=1'" in
  match curl with
  | None ->
      fail "Expected a curl command, got nothing"
  | Some s ->
      if s != expected
      then fail ("Expected: '" ^ expected ^ "', got '" ^ s ^ "'.")
      else pass


let fluid_ac_validate_on_lose_focus (m : model) : testResult =
  match onlyExpr m with
  | Some (EFieldAccess (_, EVariable (_, "request"), "body")) ->
      pass
  | e ->
      fail
        ( "Expected: `request.body`, got `"
        ^ showOption FluidPrinter.eToHumanString e
        ^ "`" )


let upload_pkg_fn_as_admin (_m : model) : testResult = pass

let use_pkg_fn (_m : model) : testResult = pass

let fluid_show_docs_for_command_on_selected_code (_m : model) : testResult =
  pass


let fluid_bytes_response (_m : model) : testResult = pass

let double_clicking_blankor_selects_it (_m : model) : testResult = pass

let abridged_sidebar_content_visible_on_hover (_m : model) : testResult = pass

let abridged_sidebar_category_icon_click_disabled (_m : model) : testResult =
  pass


let function_docstrings_are_valid (m : model) : testResult =
  let open PrettyDocs in
  let failed =
    m.functions.builtinFunctions
    |> List.filterMap ~f:(fun fn ->
           match convert_ fn.fnDescription with
           | ParseSuccess _ ->
               None
           | ParseFail messages ->
               Some (fn.fnName, messages))
  in
  if List.isEmpty failed
  then pass
  else
    let nl = " \n " in
    let combineErrors errors =
      errors
      |> List.map ~f:(fun (fnname, messages) ->
             let problems =
               messages
               |> List.map ~f:(fun (txt, msg) -> msg ^ " in \"" ^ txt ^ "\"")
               |> String.join ~sep:nl
             in
             fnname ^ nl ^ problems)
      |> String.join ~sep:nl
    in
    fail ~f:combineErrors failed


let record_consent_saved_across_canvases (_m : model) : testResult = pass

(* let exe_flow_fades (_m : model) : testResult = pass *)

let unexe_code_unfades_on_focus (_m : model) : testResult = pass

let create_from_404 (_m : model) = pass

let unfade_command_palette (_m : model) : testResult = pass

let redo_analysis_on_toggle_erail (_m : model) : testResult = pass

let redo_analysis_on_commit_ff (_m : model) : testResult = pass

let package_function_references_work (_m : model) : testResult = pass

let focus_on_secret_field_on_insert_modal_open (_m : model) : testResult = pass

let trigger (test_name : string) : integrationTestState =
  let name = String.dropLeft ~count:5 test_name in
  IntegrationTestExpectation
    ( match name with
    | "enter_changes_state" ->
        enter_changes_state
    | "field_access_closes" ->
        field_access_closes
    | "field_access_pipes" ->
        field_access_pipes
    | "tabbing_works" ->
        tabbing_works
    | "autocomplete_highlights_on_partial_match" ->
        autocomplete_highlights_on_partial_match
    | "no_request_global_in_non_http_space" ->
        no_request_global_in_non_http_space
    | "ellen_hello_world_demo" ->
        ellen_hello_world_demo
    | "editing_headers" ->
        editing_headers
    | "switching_from_http_to_cron_space_removes_leading_slash" ->
        switching_from_http_to_cron_space_removes_leading_slash
    | "switching_from_http_to_repl_space_removes_leading_slash" ->
        switching_from_http_to_repl_space_removes_leading_slash
    | "switching_from_http_space_removes_variable_colons" ->
        switching_from_http_space_removes_variable_colons
    | "switching_to_http_space_adds_slash" ->
        switching_to_http_space_adds_slash
    | "switching_from_default_repl_space_removes_name" ->
        switching_from_default_repl_space_removes_name
    | "tabbing_through_let" ->
        tabbing_through_let
    | "rename_db_fields" ->
        rename_db_fields
    | "rename_db_type" ->
        rename_db_type
    | "feature_flag_works" ->
        feature_flag_works
    | "rename_function" ->
        rename_function
    | "feature_flag_in_function" ->
        feature_flag_in_function
    | "execute_function_works" ->
        execute_function_works
    | "correct_field_livevalue" ->
        correct_field_livevalue
    | "int_add_with_float_error_includes_fnname" ->
        int_add_with_float_error_includes_fnname
    | "fluid_execute_function_shows_live_value" ->
        fluid_execute_function_shows_live_value
    | "function_version_renders" ->
        function_version_renders
    | "delete_db_col" ->
        delete_db_col
    | "cant_delete_locked_col" ->
        cant_delete_locked_col
    | "passwords_are_redacted" ->
        passwords_are_redacted
    | "select_route" ->
        select_route
    | "function_analysis_works" ->
        function_analysis_works
    | "jump_to_error" ->
        jump_to_error
    | "fourohfours_parse" ->
        fourohfours_parse
    | "fn_page_returns_to_lastpos" ->
        fn_page_returns_to_lastpos
    | "fn_page_to_handler_pos" ->
        fn_page_to_handler_pos
    | "autocomplete_visible_height" ->
        autocomplete_visible_height
    | "load_with_unnamed_function" ->
        load_with_unnamed_function
    | "create_new_function_from_autocomplete" ->
        create_new_function_from_autocomplete
    | "extract_from_function" ->
        extract_from_function
    | "fluid_single_click_on_token_in_deselected_handler_focuses" ->
        fluid_single_click_on_token_in_deselected_handler_focuses
    | "fluid_click_2x_on_token_places_cursor" ->
        fluid_click_2x_on_token_places_cursor
    | "fluid_click_2x_in_function_places_cursor" ->
        fluid_click_2x_in_function_places_cursor
    | "fluid_doubleclick_selects_token" ->
        fluid_doubleclick_selects_token
    | "fluid_doubleclick_selects_word_in_string" ->
        fluid_doubleclick_selects_word_in_string
    | "fluid_doubleclick_with_alt_selects_expression" ->
        fluid_doubleclick_with_alt_selects_expression
    | "fluid_doubleclick_selects_entire_fnname" ->
        fluid_doubleclick_selects_entire_fnname
    | "fluid_shift_right_selects_chars_in_front" ->
        fluid_shift_right_selects_chars_in_front
    | "fluid_shift_left_selects_chars_at_back" ->
        fluid_shift_left_selects_chars_at_back
    | "fluid_undo_redo_happen_exactly_once" ->
        fluid_undo_redo_happen_exactly_once
    | "fluid_ctrl_left_on_string" ->
        fluid_ctrl_left_on_string
    | "fluid_ctrl_right_on_string" ->
        fluid_ctrl_right_on_string
    | "fluid_ctrl_left_on_empty_match" ->
        fluid_ctrl_left_on_empty_match
    | "varnames_are_incomplete" ->
        varnames_are_incomplete
    | "center_toplevel" ->
        center_toplevel
    | "max_callstack_bug" ->
        max_callstack_bug
    | "sidebar_opens_function" ->
        sidebar_opens_function
    | "empty_fn_never_called_result" ->
        empty_fn_never_called_result
    | "empty_fn_been_called_result" ->
        empty_fn_been_called_result
    | "sha256hmac_for_aws" ->
        sha256hmac_for_aws
    | "fluid_fn_pg_change" ->
        fluid_fn_pg_change
    | "fluid_creating_an_http_handler_focuses_the_verb" ->
        fluid_creating_an_http_handler_focuses_the_verb
    | "fluid_tabbing_from_an_http_handler_spec_to_ast" ->
        fluid_tabbing_from_an_http_handler_spec_to_ast
    | "fluid_tabbing_from_handler_spec_past_ast_back_to_verb" ->
        fluid_tabbing_from_handler_spec_past_ast_back_to_verb
    | "fluid_shift_tabbing_from_handler_ast_back_to_route" ->
        fluid_shift_tabbing_from_handler_ast_back_to_route
    | "fluid_test_copy_request_as_curl" ->
        fluid_test_copy_request_as_curl
    | "fluid_ac_validate_on_lose_focus" ->
        fluid_ac_validate_on_lose_focus
    | "upload_pkg_fn_as_admin" ->
        upload_pkg_fn_as_admin
    | "use_pkg_fn" ->
        use_pkg_fn
    | "fluid_show_docs_for_command_on_selected_code" ->
        fluid_show_docs_for_command_on_selected_code
    | "fluid-bytes-response" ->
        fluid_bytes_response
    | "double_clicking_blankor_selects_it" ->
        double_clicking_blankor_selects_it
    | "abridged_sidebar_content_visible_on_hover" ->
        abridged_sidebar_content_visible_on_hover
    | "abridged_sidebar_category_icon_click_disabled" ->
        abridged_sidebar_category_icon_click_disabled
    | "function_docstrings_are_valid" ->
        function_docstrings_are_valid
    | "record_consent_saved_across_canvases" ->
        record_consent_saved_across_canvases
    (* | "exe_flow_fades" ->
        exe_flow_fades *)
    | "unexe_code_unfades_on_focus" ->
        unexe_code_unfades_on_focus
    | "create_from_404" ->
        create_from_404
    | "unfade_command_palette" ->
        unfade_command_palette
    | "redo_analysis_on_toggle_erail" ->
        redo_analysis_on_toggle_erail
    | "redo_analysis_on_commit_ff" ->
        redo_analysis_on_commit_ff
    | "package_function_references_work" ->
        package_function_references_work
    | "focus_on_secret_field_on_insert_modal_open" ->
        focus_on_secret_field_on_insert_modal_open
    | n ->
        fun _ -> fail ("Test " ^ n ^ " not added to IntegrationTest.trigger") )
