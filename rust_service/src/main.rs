use hyper::{Body, Request, Response, Server};
use hyper::service::{make_service_fn, service_fn};
use std::convert::Infallible;

async fn handle_req(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    let body = "Hello from Rust Service (Compute tasks)\n";
    Ok(Response::new(Body::from(body)))
}

async fn health_check(_req: Request<Body>) -> Result<Response<Body>, Infallible> {
    Ok(Response::new(Body::from("OK")))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = ([0, 0, 0, 0], 3000).into();
    println!("Rust Service => 0.0.0.0:3000 (Use /health)");

    let make_svc = make_service_fn(|_conn| async {
        Ok::<_, Infallible>(service_fn(|req| async move {
            match req.uri().path() {
                "/health" => health_check(req).await,
                _ => handle_req(req).await,
            }
        }))
    });

    Server::bind(&addr).serve(make_svc).await?;
    Ok(())
}
