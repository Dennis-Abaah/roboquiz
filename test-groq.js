const apiKey = "gsk_mXK";

async function testGroq() {
    try {
        const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                model: "llama3-8b-8192",
                messages: [
                    { role: "system", content: "You are a helpful assistant." },
                    { role: "user", content: "Test" }
                ],
                temperature: 0.3
            })
        });
        
        if (!response.ok) {
            console.error(await response.text());
        } else {
            console.log(await response.json());
        }
    } catch(e) {
        console.error(e);
    }
}
testGroq();
