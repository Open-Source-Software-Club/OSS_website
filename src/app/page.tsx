import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-6 md:p-24">
      <Card className="w-full max-w-lg">
        <CardHeader className="text-center">
          <div className="mb-2 flex justify-center">
            <Badge variant="secondary">Open Source Software Club</Badge>
          </div>
          <CardTitle asChild className="text-3xl font-bold tracking-tight">
            <h1>SVIT OSS Club</h1>
          </CardTitle>
          <CardDescription>
            Scaffolded Next.js 15 project with TypeScript strict, Tailwind CSS, and shadcn/ui.
          </CardDescription>
        </CardHeader>
        <CardContent className="flex justify-center gap-4">
          <Button variant="default">Get Started</Button>
          <Button variant="outline">Learn More</Button>
        </CardContent>
      </Card>
    </main>
  );
}
