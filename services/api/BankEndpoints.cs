using Microsoft.EntityFrameworkCore;

namespace Budgetism.Api;

public static class BankEndpoints
{
    public static void MapServerBank(this WebApplication app)
    {
        var group = app.MapGroup("/api/bank/sandbox").RequireRateLimiting("bank");
        group.MapGet("/state", (HttpContext ctx, FinanceDb db, ServerBank bank, int? offset, int? version) =>
            Run(ctx, db, async token => Results.Ok(await bank.StateAsync(Owner(ctx), offset ?? 0, version, token))));
        group.MapPost("/connect", (HttpContext ctx, FinanceDb db, ServerBank bank, BankConnectInput input) =>
            Run(ctx, db, async token => Results.Ok(await bank.ConnectAsync(Owner(ctx), input, token))));
        group.MapPost("/map", (HttpContext ctx, FinanceDb db, ServerBank bank, BankMapInput input) =>
            Run(ctx, db, async token => Results.Ok(await bank.MapAsync(Owner(ctx), input, token))));
        group.MapPost("/refresh", (HttpContext ctx, FinanceDb db, ServerBank bank, BankRefreshInput input) =>
            Run(ctx, db, async token => Results.Ok(await bank.RefreshAsync(Owner(ctx), input, token))));
        group.MapPost("/active", (HttpContext ctx, FinanceDb db, ServerBank bank, BankActiveInput input) =>
            Run(ctx, db, async token => Results.Ok(await bank.ActiveAsync(Owner(ctx), input, token))));
        group.MapPost("/review", (HttpContext ctx, FinanceDb db, ServerBank bank, BankReviewInput input) =>
            Run(ctx, db, async token => Results.Ok(await bank.ReviewAsync(Owner(ctx), input, token))));
        group.MapPost("/review-batch", (HttpContext ctx, FinanceDb db, ServerBank bank, BankReviewBatchInput input) =>
            Run(ctx, db, async token => Results.Ok(await bank.ReviewBatchAsync(Owner(ctx), input, token))));
    }
    private static Guid Owner(HttpContext ctx) => (Guid)ctx.Items["ownerId"]!;
    private static async Task<IResult> Run(HttpContext ctx, FinanceDb db, Func<CancellationToken, Task<IResult>> action)
    {
        ctx.Response.Headers.CacheControl = "no-store";
        if (Environment.GetEnvironmentVariable("PLAID_SANDBOX_REVIEW_ENABLED") != "true")
            return Results.Json(new { error = "sandbox_review_disabled" }, statusCode: 503);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ctx.RequestAborted);
        timeout.CancelAfter(TimeSpan.FromSeconds(90));
        try
        {
            if (!await BankSchema.ReadyAsync(db, timeout.Token))
                return Results.Json(new { error = "storage_upgrade_required" }, statusCode: 503);
            return await action(timeout.Token);
        }
        catch (BankRuleException error) { return Results.Json(new { error = error.Code }, statusCode: error.Status); }
        catch (DbUpdateException) { return Results.Json(new { error = "operation_conflict" }, statusCode: 409); }
        catch (Exception)
        {
            // Do not return or log exception messages, provider payloads, or secret paths.
            return Results.Json(new { error = "sandbox_operation_failed" }, statusCode: 502);
        }
    }
}
