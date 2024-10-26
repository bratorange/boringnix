use axum::{
    extract::Path,
    routing::{get, post},
    Router, Form,
};
use std::fs;
use std::path::PathBuf;
use std::process::exit;
use serde::Deserialize;
use tower_http::trace::TraceLayer;
use tracing::{info, warn, error, Level};

#[derive(Deserialize)]
struct ModuleForm {
    module: String,
}

// Function to check and create the modules directory
fn ensure_modules_directory() -> std::io::Result<()> {
    let modules_path = PathBuf::from("modules");
    let modules_path_string = modules_path.display();
    if !modules_path.exists() {
        info!("Directory {modules_path_string} does not exist. Exiting...");
        info!("Current directory: {current_dir}", current_dir = std::env::current_dir().unwrap().display());
        exit(1)
    } else {
        info!("Found modules directory at {modules_path_string}");
    }
    Ok(())
}

async fn index() -> axum::response::Html<String> {
    info!("Serving index page");
    axum::response::Html(
        fs::read_to_string("static/static.html")
            .unwrap_or_else(|e| {
                error!("Failed to read static.html: {}", e);
                "Error loading static.html".to_string()
            })
    )
}

async fn serve_module(Path(module): Path<String>) -> axum::response::Response {
    info!("Serving module: {}", module);
    let path = PathBuf::from(format!("modules/{}.nix", module));

    if path.exists() {
        match fs::read_to_string(&path) {
            Ok(content) => {
                info!("Successfully served module: {}", module);
                axum::response::Response::builder()
                    .header("Content-Type", "text/plain")
                    .body(content.into())
                    .unwrap()
            }
            Err(e) => {
                error!("Failed to read module {}: {}", module, e);
                axum::response::Response::builder()
                    .status(500)
                    .body("Error reading module".into())
                    .unwrap()
            }
        }
    } else {
        warn!("Module not found: {}", module);
        axum::response::Response::builder()
            .status(404)
            .body(format!("<body>No module for <b>\
            {module} </b> exists. You could add one at\
             <a href=\"https://github.com/bratorange/boringnix\"> github.com/bratorange/boringnix </a>\
            </body>").into())
            .unwrap()
    }
}

async fn forward_module(Form(form): Form<ModuleForm>) -> axum::response::Redirect {
    // Sanitize module name
    let module = form.module.replace("..", "").replace("/", "");
    info!("Forwarding to module: {}", module);
    axum::response::Redirect::to(&format!("/{}", module))
}
#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_target(false)
        .with_level(true)
        .with_file(true)
        .with_line_number(true)
        .with_thread_ids(true)
        .with_thread_names(true)
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env()
            .add_directive(Level::INFO.into())
            .add_directive("tower_http=debug".parse().unwrap()))
        .init();

    info!("Starting BoringNix Module Server");

    // Check and create modules directory
    if let Err(e) = ensure_modules_directory() {
        error!("Failed to create modules directory: {}", e);
        std::process::exit(1);
    }

    let app = Router::new()
        .route("/", get(index))
        .route("/", post(forward_module))
        .route("/:module", get(serve_module))
        .layer(TraceLayer::new_for_http());

    let addr = "127.0.0.1:8005";
    info!("Listening on {}", addr);

    match tokio::net::TcpListener::bind(addr).await {
        Ok(listener) => {
            info!("Server started successfully");
            if let Err(e) = axum::serve(listener, app).await {
                error!("Server error: {}", e);
                std::process::exit(1);
            }
        }
        Err(e) => {
            error!("Failed to bind to {}: {}", addr, e);
            std::process::exit(1);
        }
    }
}