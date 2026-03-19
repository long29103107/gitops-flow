var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello from Product API");

app.MapGet("/health", () => "product-api-ok"); 

app.Run(); 