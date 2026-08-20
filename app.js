const openrouterKey =
  document.getElementById("openrouterKey");

const model =
  document.getElementById("model");

const systemPrompt =
  document.getElementById("systemPrompt");

const fishKey =
  document.getElementById("fishKey");

const voiceId =
  document.getElementById("voiceId");

const message =
  document.getElementById("message");

const send =
  document.getElementById("send");

const mic =
  document.getElementById("mic");

const chat =
  document.getElementById("chat");

const status =
  document.getElementById("status");

const avatar =
  document.getElementById("avatar");


let conversation = [];


// =====================================================
// LOCAL STORAGE
// =====================================================

openrouterKey.value =
  localStorage.getItem(
    "verity_openrouter_key"
  ) || "";

fishKey.value =
  localStorage.getItem(
    "verity_fish_key"
  ) || "";

model.value =
  localStorage.getItem(
    "verity_model"
  ) ||
  "openai/gpt-oss-20b:free";

systemPrompt.value =
  localStorage.getItem(
    "verity_prompt"
  ) ||
  "Tu es Verity, une IA sympathique, naturelle et expressive. Réponds en français.";

voiceId.value =
  localStorage.getItem(
    "verity_voice"
  ) ||
  "8c7928c5db264ae385dfc208431e24b9";


openrouterKey.oninput = () =>
  localStorage.setItem(
    "verity_openrouter_key",
    openrouterKey.value
  );

fishKey.oninput = () =>
  localStorage.setItem(
    "verity_fish_key",
    fishKey.value
  );

model.oninput = () =>
  localStorage.setItem(
    "verity_model",
    model.value
  );

systemPrompt.oninput = () =>
  localStorage.setItem(
    "verity_prompt",
    systemPrompt.value
  );

voiceId.oninput = () =>
  localStorage.setItem(
    "verity_voice",
    voiceId.value
  );


// =====================================================
// CHAT
// =====================================================

function addMessage(
  text,
  type
) {

  const div =
    document.createElement("div");

  div.className =
    "message " + type;

  div.textContent =
    text;

  chat.appendChild(div);

  chat.scrollTop =
    chat.scrollHeight;

}


// =====================================================
// OPENROUTER
// =====================================================

async function askVerity(text) {

  if (!openrouterKey.value.trim()) {

    diagnostic(
      "Aucune clé OpenRouter.",
      "error"
    );

    addMessage(
      "⚠️ Ajoute ta clé OpenRouter dans ⚙️.",
      "error"
    );

    return;

  }


  diagnostic(
    "Début de la requête OpenRouter...",
    "info"
  );


  status.textContent =
    "🤔 Verity réfléchit...";


  send.disabled = true;
  mic.disabled = true;


  try {

    const body = {

      model:
        model.value.trim(),

      messages: [

        {
          role: "system",

          content:
            systemPrompt.value
        },

        ...conversation,

        {
          role: "user",

          content: text
        }

      ]

    };


    diagnostic(
      `Modèle : ${body.model}`,
      "info"
    );


    const response =
      await fetch(
        "https://openrouter.ai/api/v1/chat/completions",
        {

          method: "POST",

          headers: {

            "Authorization":
              "Bearer " +
              openrouterKey.value.trim(),

            "Content-Type":
              "application/json",

            "HTTP-Referer":
              location.href,

            "X-Title":
              "Verity AI"

          },

          body:
            JSON.stringify(body)

        }
      );


    diagnostic(
      `OpenRouter HTTP ${response.status}`,
      response.ok
        ? "ok"
        : "error"
    );


    const data =
      await response.json();


    if (!response.ok) {

      throw new Error(

        data?.error?.message ||

        `OpenRouter HTTP ${response.status}`

      );

    }


    const answer =
      data?.choices?.[0]?.message?.content;


    if (!answer) {

      throw new Error(
        "OpenRouter n'a retourné aucun texte."
      );

    }


    diagnostic(
      "Réponse OpenRouter reçue ✓",
      "ok"
    );


    conversation.push({

      role: "user",

      content: text

    });


    conversation.push({

      role: "assistant",

      content: answer

    });


    addMessage(
      answer,
      "ai"
    );


    status.textContent =
      "";


    await speak(answer);


  } catch (error) {

    diagnosticError(error);

    addMessage(
      "❌ " + error.message,
      "error"
    );

    status.textContent =
      "";

  }


  send.disabled = false;
  mic.disabled = false;

}


// =====================================================
// FISH AUDIO
// =====================================================

async function speak(text) {

  const key =
    fishKey.value.trim();


  if (!key) {

    diagnostic(
      "Pas de clé Fish Audio → TTS navigateur.",
      "info"
    );

    browserSpeech(text);

    return;

  }


  diagnostic(
    "Requête Fish Audio...",
    "info"
  );


  avatar.classList.add(
    "speaking"
  );


  status.textContent =
    "🔊 Verity parle...";


  try {

    const response =
      await fetch(
        "https://api.fish.audio/v1/tts",
        {

          method: "POST",

          headers: {

            "Authorization":
              "Bearer " + key,

            "Content-Type":
              "application/json",

            "model":
              "s2-pro"

          },

          body:
            JSON.stringify({

              text,

              reference_id:
                voiceId.value.trim(),

              format:
                "mp3",

              latency:
                "balanced"

            })

        }
      );


    diagnostic(
      `Fish Audio HTTP ${response.status}`,
      response.ok
        ? "ok"
        : "error"
    );


    if (!response.ok) {

      const errorText =
        await response.text();

      throw new Error(
        `Fish Audio HTTP ${response.status}: ${errorText}`
      );

    }


    const blob =
      await response.blob();


    diagnostic(
      `Audio reçu : ${blob.size} octets`,
      "ok"
    );


    const url =
      URL.createObjectURL(blob);


    const audio =
      new Audio(url);


    audio.onended = () => {

      avatar.classList.remove(
        "speaking"
      );

      status.textContent =
        "";

      URL.revokeObjectURL(url);

    };


    audio.onerror = () => {

      avatar.classList.remove(
        "speaking"
      );

      status.textContent =
        "❌ Lecture audio impossible.";

      diagnostic(
        "Le navigateur n'a pas réussi à lire l'audio.",
        "error"
      );

      URL.revokeObjectURL(url);

    };


    await audio.play();


  } catch (error) {

    avatar.classList.remove(
      "speaking"
    );

    status.textContent =
      "";


    diagnosticError(error);


    /*
      Fallback navigateur.
      Donc même si Fish Audio échoue,
      Verity peut quand même parler.
    */

    browserSpeech(text);

  }

}


// =====================================================
// TTS NAVIGATEUR
// =====================================================

function browserSpeech(text) {

  if (!("speechSynthesis" in window)) {

    diagnostic(
      "speechSynthesis indisponible.",
      "error"
    );

    return;

  }


  speechSynthesis.cancel();


  const utterance =
    new SpeechSynthesisUtterance(text);


  utterance.lang =
    "fr-FR";


  utterance.rate =
    1;


  utterance.pitch =
    1;


  utterance.onstart = () => {

    avatar.classList.add(
      "speaking"
    );

    status.textContent =
      "🔊 Verity parle...";

  };


  utterance.onend = () => {

    avatar.classList.remove(
      "speaking"
    );

    status.textContent =
      "";

  };


  speechSynthesis.speak(
    utterance
  );

}


// =====================================================
// SEND
// =====================================================

async function sendMessage() {

  const text =
    message.value.trim();


  if (!text)
    return;


  addMessage(
    text,
    "user"
  );


  message.value =
    "";


  await askVerity(text);

}


send.addEventListener(
  "click",
  sendMessage
);


message.addEventListener(
  "keydown",
  event => {

    if (
      event.key === "Enter" &&
      !event.shiftKey
    ) {

      event.preventDefault();

      sendMessage();

    }

  }
);


// =====================================================
// MICRO
// =====================================================

const SpeechRecognition =
  window.SpeechRecognition ||
  window.webkitSpeechRecognition;


if (!SpeechRecognition) {

  diagnostic(
    "SpeechRecognition non disponible dans ce navigateur.",
    "error"
  );

  mic.disabled = true;

} else {

  diagnostic(
    "SpeechRecognition disponible ✓",
    "ok"
  );


  const recognition =
    new SpeechRecognition();


  recognition.lang =
    "fr-FR";


  recognition.continuous =
    false;


  recognition.interimResults =
    false;


  recognition.onstart = () => {

    mic.classList.add(
      "listening"
    );

    mic.textContent =
      "🛑";

    status.textContent =
      "🎤 Je t'écoute...";


    diagnostic(
      "Micro activé.",
      "ok"
    );

  };


  recognition.onresult =
    event => {

      const text =
        event.results[0][0].transcript;


      diagnostic(
        "Texte reconnu : " + text,
        "ok"
      );


      addMessage(
        text,
        "user"
      );


      askVerity(text);

    };


  recognition.onerror =
    event => {

      diagnostic(
        "Micro : " +
        event.error,
        "error"
      );

      status.textContent =
        "❌ Micro : " +
        event.error;

    };


  recognition.onend = () => {

    mic.classList.remove(
      "listening"
    );

    mic.textContent =
      "🎤";

  };


  mic.addEventListener(
    "click",
    () => {

      try {

        recognition.start();

      } catch (error) {

        diagnosticError(error);

      }

    }
  );

}


// =====================================================
// INITIAL DIAGNOSTIC
// =====================================================

diagnostic(
  "Verity initialisée ✓",
  "ok"
);

diagnostic(
  "OpenRouter : " +
  (openrouterKey.value
    ? "clé présente"
    : "clé absente"),
  openrouterKey.value
    ? "ok"
    : "error"
);

diagnostic(
  "Fish Audio : " +
  (fishKey.value
    ? "clé présente"
    : "clé absente"),
  fishKey.value
    ? "ok"
    : "info"
);

diagnostic(
  "Voice ID : " +
  voiceId.value,
  "info"
);
