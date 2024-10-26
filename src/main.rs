use axum::{
    extract::Path,
    routing::{get, post},
    Router, Form,
};
use std::fs;
use std::path::PathBuf;
use serde::Deserialize;
use tower_http::trace::TraceLayer;
use tracing::{info, warn, error, Level};

#[derive(Deserialize)]
struct TemplateForm {
    template: String,
}

// Function to check and create the modules directory
fn ensure_modules_directory() -> std::io::Result<()> {
    let modules_path = PathBuf::from("modules");
    if !modules_path.exists() {
        info!("Creating modules directory");
        fs::create_dir(&modules_path)?;
        // Create a default test.nix file if it doesn't exist
        let test_path = modules_path.join("test.nix");
        if !test_path.exists() {
            info!("Creating default test.nix template");
            fs::write(
                test_path,
                "{ config, pkgs, ... }:\n{\n  # Default template\n  services.nextcloud = {\n    enable = true;\n    package = pkgs.nextcloud27;\n    hostName = \"nextcloud.example.com\";\n    # Add more configuration options here\n  };\n}\n"
            )?;
        }
    } else {
        info!("Modules directory exists");
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

async fn serve_template(Path(template): Path<String>) -> axum::response::Response {
    info!("Serving template: {}", template);
    let path = PathBuf::from(format!("modules/{}.nix", template));

    if path.exists() {
        match fs::read_to_string(&path) {
            Ok(content) => {
                info!("Successfully served template: {}", template);
                axum::response::Response::builder()
                    .header("Content-Type", "text/plain")
                    .body(content.into())
                    .unwrap()
            }
            Err(e) => {
                error!("Failed to read template {}: {}", template, e);
                axum::response::Response::builder()
                    .status(500)
                    .body("Error reading template".into())
                    .unwrap()
            }
        }
    } else {
        warn!("Template not found: {}", template);
        axum::response::Response::builder()
            .status(404)
            .body("{} not found".into())
            .unwrap()
    }
}

async fn forward_template(Form(form): Form<TemplateForm>) -> axum::response::Redirect {
    // Sanitize template name
    let template = form.template.replace("..", "").replace("/", "");
    info!("Forwarding to template: {}", template);
    axum::response::Redirect::to(&format!("/{}", template))
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

    info!("Starting BoringNix Template Server");

    // Check and create modules directory
    if let Err(e) = ensure_modules_directory() {
        error!("Failed to create modules directory: {}", e);
        std::process::exit(1);
    }

    let app = Router::new()
        .route("/", get(index))
        .route("/", post(forward_template))
        .route("/:template", get(serve_template))
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