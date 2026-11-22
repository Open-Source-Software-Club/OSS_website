export default function ContactPage() {
  return (
    <main className="mx-auto w-full max-w-[1200px] px-4 py-10 sm:px-6 sm:py-16">
      <h1 className="text-[clamp(2.5rem,8vw,5rem)] font-bold">Contact</h1>
      <form className="mt-8 grid max-w-xl gap-4">
        <label className="grid gap-2">
          Name
          <input
            className="min-h-11 w-full rounded-md border border-border bg-background px-3"
            name="name"
          />
        </label>
        <label className="grid gap-2">
          Email
          <input
            type="email"
            className="min-h-11 w-full rounded-md border border-border bg-background px-3"
            name="email"
          />
        </label>
        <button
          type="submit"
          className="min-h-11 rounded-md bg-primary px-5 text-primary-foreground"
        >
          Send
        </button>
      </form>
    </main>
  );
}
