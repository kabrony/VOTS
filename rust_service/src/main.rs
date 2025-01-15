use hyper::{Body, Request, Response, Server, header::CONTENT_TYPE, StatusCode};
use hyper::service::{make_service_fn, service_fn};
use std::collections::HashMap;
use std::convert::Infallible;
use reqwest;

// parse_query: splits "prompt=Hello&x=1" into a HashMap
fn parse_query(query_str: &str) -> HashMap<String, String> {
    let mut params = HashMap::new();
    for pair in query_str.split('&') {
        let mut kv = pair.splitn(2, '=');
        let key = kv.next().unwrap_or("").to_string();
        let val = kv.next().unwrap_or("").to_string();
        if !key.is_empty() {
            params.insert(key, val);
        }
    }
    params
}

// /health => basic check
async fn health_handler() -> Result<Response<Body>, Infallible> {
    let resp = Response::new(Body::from("OK"));
    Ok(resp)
}

// /compute => parse 'prompt' & call synergy agent
async fn compute_handler(query: &str) -> Result<Response<Body>, Infallible> {
    let params = parse_query(query);
    let prompt = params.get("prompt").map(|s| s.as_str()).unwrap_or("none");

    // Call Python synergy agent at http://python_agent:9000/chat_gpt?prompt=...
    // In Docker Compose, "python_agent" is the service name, port 9000 is mapped internally.
    // We'll do a GET request with prompt param:
    let synergy_url = format!("http://python_agent:9000/chat_gpt?prompt={}", prompt);

    // Make the request. If it fails, we return an error string.
    let synergy_resp = match reqwest::get(&synergy_url).await {
        Ok(resp) => match resp.text().await {
            Ok(text) => text,
            Err(e) => format!("Error reading synergy text: {}", e)
        },
        Err(e) => format!("Error calling synergy agent: {}", e)
    };

    let answer = format!("Rust synergy result => Python synergy says:\n{}\n", synergy_resp);

    let mut http_resp = Response::new(Body::from(answer));
    http_resp.headers_mut().insert(CONTENT_TYPE, "text/plain".parse().unwrap());
    Ok(http_resp)
}

// default => hello from Rust
async fn root_handler() -> Result<Response<Body>, Infallible> {
    let msg = "Hello from Rust. Try /health or /compute?prompt=Hello\n";
    let mut resp = Response::new(Body::from(msg));
    resp.headers_mut().insert(CONTENT_TYPE, "text/plain".parse().unwrap());
    Ok(resp)
}

async fn handle_req(req: Request<Body>) -> Result<Response<Body>, Infallible> {
    let path = req.uri().path();
    let query_str = req.uri().query().unwrap_or("");

    match path {
        "/health" => health_handler().await,
        "/compute" => compute_handler(query_str).await,
        _ => root_handler().await,
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let addr = ([0, 0, 0, 0], 3000).into();
    println!("Rust Service => listening on 0.0.0.0:3000");
    println!("Try /health or /compute?prompt=Hello => calls Python synergy agent!");

    let make_svc = make_service_fn(|_conn| async {
        Ok::<_, Infallible>(service_fn(|req| async move {
            handle_req(req).await
        }))
    });

    Server::bind(&addr).serve(make_svc).await?;
    Ok(())
}
