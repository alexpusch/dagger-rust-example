fn add(a: &str, b: &str) -> String {
    format!("{}, {}!", a, b)
}

#[tokio::main]
async fn main() {
    println!("{}", add("Hello", "world"));
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn add_works() {
        assert_eq!(add("first", "seconds"), "first, seconds!");
    }
}
