import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { category, title, context, count } = await req.json()

    // Grab the API key from the environment variables (set via Supabase CLI)
    const apiKey = Deno.env.get('GROQ_API_KEY')
    if (!apiKey) {
      throw new Error('GROQ_API_KEY environment variable is missing')
    }

    const systemPrompt = `You are an expert robotics educator creating a multiple-choice quiz for middle school students.
You must output ONLY a valid JSON array of objects. No markdown formatting, no code blocks, no text outside the JSON array.
Format required:
[
  {
    "question": "...",
    "A": "...",
    "B": "...",
    "C": "...",
    "D": "...",
    "correct": "A"
  }
]
"correct" MUST be exactly one character: "A", "B", "C", or "D".`;

    const userPrompt = `Create exactly ${count} questions for a robotics quiz.
Category: ${category}
Title: ${title}
Context/Objective: ${context || 'General knowledge about ' + category + ' robotics systems.'}`;

    // Make the request to Groq API
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt }
        ],
        temperature: 0.3
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Groq API Error: ${response.status} - ${errorText}`)
    }

    const data = await response.json()
    let content = data.choices[0].message.content.trim()

    // Safety cleanup in case LLM wrapped in markdown
    if (content.startsWith('```json')) content = content.substring(7)
    if (content.startsWith('```')) content = content.substring(3)
    if (content.endsWith('```')) content = content.substring(0, content.length - 3)

    const questionsArray = JSON.parse(content.trim())

    // Return the questions array directly to the client
    return new Response(JSON.stringify(questionsArray), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error(error)
    const err = error as Error
    return new Response(JSON.stringify({ error: err.message || String(error) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
