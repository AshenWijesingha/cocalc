import * as React from "react";
import * as ReactDOM from "react-dom";
import styled from "styled-components";
import * as querystring from "query-string";

import {
  ProjectSelector,
  ProjectContainer,
  //SelectedItemsList,
  //ConfigurationPage
} from "./view";
import * as API from "./api";
import { GlobalState, Route } from "./state/types";
import { reducer } from "./state/reducers";
import { initial_global_state } from "./state/values";
import { assert_never } from "./helpers";

// TODO: Put this somewhere ./state
// Returns a shallow copy of global_state with a new context attached via url search query
function with_data_from_params(global_state: GlobalState): GlobalState {
  const query_params = querystring.parse(window.location.search);
  if (query_params.id_token == undefined) {
    throw new Error("id_token was undefined");
  }
  if (Array.isArray(query_params.id_token)) {
    throw new Error("id_token recieved as an array. Should be a single value");
  }
  if (query_params.nonce == undefined) {
    throw new Error("nonce was undefined");
  }
  if (Array.isArray(query_params.nonce)) {
    throw new Error("nonce recieved as an array. Should be a single value");
  }

  return {
    ...global_state,
    context: {
      id_token: query_params.id_token,
      nonce: query_params.nonce
    }
  };
}

function App() {
  const [state, dispatch] = React.useReducer(
    reducer,
    initial_global_state,
    with_data_from_params
  );

  React.useEffect(() => {
    const fetchData = async () => {
      const projects = await API.fetch_projects();
      const account_info = await API.fetch_self();
      dispatch({
        type: "initial_load",
        projects,
        account_info
      });
    };

    fetchData();
  }, []);

  let content = (
    <>
      The route: {state.route} is not yet implemented. Here's the state!
      <br />
      {JSON.stringify(state)}
    </>
  );

  if (!state.loading && state.account_info) {
    switch (state.route) {
      case Route.Home:
        content = (
          <ProjectSelector
            projects={state.projects}
            account_id={state.account_info.account_id}
            dispatch={dispatch}
          />
        );
        break;
      case Route.Project:
        content = (
          <ProjectContainer
            project_id={state.opened_project_id}
            projects={state.projects}
            current_path={state.current_path}
            file_listings={state.file_listings[state.opened_project_id]}
            opened_directories={
              state.opened_directories[state.opened_project_id]
            }
            selected_entries={state.selected_entries[state.opened_project_id]}
            excluded_entries={state.excluded_entries[state.opened_project_id]}
            dispatch={dispatch}
          />
        );
        break;
      default:
        assert_never(state.route);
    }
  } else if (!state.loading && !state.account_info) {
    content = (
      <div>Stuff returned but account_info is undefined. Check logs</div>
    );
  } else {
    content = <div>Loading...</div>;
  }

  return (
    <Grid>
      <HeaderContainer>Cocalc</HeaderContainer>
      <ContentContainer>{content}</ContentContainer>
      <FooterContainer>Select Project | Select Files | Configure</FooterContainer>
    </Grid>
  );
}

const Grid = styled.div`
  display: grid;
  font-size: 24px;
  grid-template-columns: 5% auto 5%;
  grid-template-rows: 30px auto 30px;
  grid-template-areas:
    "header header header"
    "left-gutter content right-gutter"
    "footer footer footer";
  width: 100vw;
  height: 100vh;
  overflow: hidden;
`;

const HeaderContainer = styled.div`
  grid-area: header;
  overflow: hidden;
  background: skyblue;
`;

const ContentContainer = styled.div`
  grid-area: content;
  overflow: scroll;
`;

const FooterContainer = styled.div`
  grid-area: footer;
  oferflow: hidden;
  background: skyblue;
`;

export function render_app() {
  ReactDOM.render(<App />, document.getElementById("cocalc-react-container"));
}
