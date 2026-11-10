#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    let endpoint = args.get(1).map(String::as_str).unwrap_or("https://edge.1molchuan.top/linuxdo");
    let target = args.get(2).map(String::as_str).unwrap_or("https://x.com/robots.txt");
    match harmonyx_doh::probe(endpoint, target).await {
        Ok(result) => println!("{result}"),
        Err(error) => { eprintln!("{error}"); std::process::exit(1); }
    }
}
