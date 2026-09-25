def headers []: nothing -> list<any> {
    [
        "CF-Access-Client-Id"
        $"($env.CF_ACCESS_CLIENT_ID)"
        "CF-Access-Client-Secret"
        $"($env.CF_ACCESS_CLIENT_SECRET)"
    ]
}

export def crawl [url: string, formats: list<string> = ["markdown"]]: nothing -> any {
    let crawl_url = $"($env.FIRECRAWL_URL)/v2/scrape"
    let res = http post --full --allow-errors -t application/json -H (headers) $crawl_url { url: $url, formats: $formats }
    | select status body

    {
        status: $res.status
        success: $res.body.success
        markdown: $res.body.data.markdown
        metadata: $res.body.data.metadata
    }
}

export def search [query: string]: nothing -> any {
    let search_url = $query | url encode | $"($env.SEARXNG_URL)/search?q=($in)&format=json"
    let res = http get --full --allow-errors -H (headers) $search_url | select status body

    $res.body.results
}
