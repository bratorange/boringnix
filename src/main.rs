use axum::{
    extract::Path,
    routing::{get, post},
    Router, Form,
};
use std::fs;
use std::path::PathBuf;
use serde::Deserialize;

#[derive(Deserialize)]
struct TemplateForm {
    template: String,
}

async fn index() -> axum::response::Html<String> {
    fs::read_to_string("static/index.html").unwrap_or_else(|_| "Error loading index.html".to_string())
}

async fn serve_template(Path(template): Path<String>) -> axum::response::Response {
    let path = PathBuf::from(format!("modules/{}.nix", template));
    if path.exists() {
        let content = fs::read_to_string(path).unwrap_or_else(|_| "Error reading template".to_string());
        axum::response::Response::builder()
            .header("Content-Type", "text/plain")
            .body(content.into())
            .unwrap()
    } else {
        axum::response::Response::builder()
            .status(404)
            .body("Template not found".into())
            .unwrap()
    }
}

async fn forward_template(Form(form): Form<TemplateForm>) -> axum::response::Redirect {
    axum::response::Redirect::to(&format!("/{}.nix", form.template))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/", get(index))
        .route("/", post(forward_template))
        .route("/:template.nix", get(serve_template));

    let listener = tokio::net::TcpListener::bind("127.0.0.1:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
