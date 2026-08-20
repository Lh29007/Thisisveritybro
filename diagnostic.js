const diagnosticBox =
  document.getElementById("diagnostic");

function diagnostic(message, type = "info") {

  if (!diagnosticBox) return;

  const line =
    document.createElement("div");

  line.className =
    "diag-" + type;

  const time =
    new Date().toLocaleTimeString();

  line.textContent =
    `[${time}] ${message}`;

  diagnosticBox.appendChild(line);

  diagnosticBox.scrollTop =
    diagnosticBox.scrollHeight;

  console.log(
    `[Verity] ${message}`
  );
}


function diagnosticError(error) {

  console.error(error);

  diagnostic(
    error?.message ||
    String(error),
    "error"
  );
}


window.addEventListener(
  "error",
  event => {

    diagnostic(
      `JavaScript: ${event.message}`,
      "error"
    );

  }
);


window.addEventListener(
  "unhandledrejection",
  event => {

    diagnostic(
      `Promise: ${event.reason}`,
      "error"
    );

  }
);


diagnostic(
  `Page chargée : ${location.href}`,
  "ok"
);


diagnostic(
  `Navigateur : ${navigator.userAgent}`,
  "info"
);


diagnostic(
  `HTTPS : ${location.protocol === "https:" ? "oui" : "non"}`,
  location.protocol === "https:"
    ? "ok"
    : "error"
);
