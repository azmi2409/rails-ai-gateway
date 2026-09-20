document.addEventListener("DOMContentLoaded", () => {
  const dialog = document.querySelector("#provider-connect-dialog");
  if (!dialog || typeof dialog.showModal !== "function") return;

  document.querySelectorAll("[data-provider-connect]").forEach((button) => {
    button.addEventListener("click", () => {
      const name = button.dataset.providerName;
      dialog.querySelector("[data-dialog-template]").value = button.dataset.template;
      dialog.querySelector("[data-dialog-logo]").src = button.dataset.logo;
      dialog.querySelector("[data-dialog-key-label]").textContent = `${name} API Key`;
      dialog.querySelector("[data-dialog-submit]").value = `Connect ${name}`;
      dialog.querySelector("#connect-dialog-title").textContent = `Connect ${name}`;
      dialog.showModal();
      dialog.querySelector("[data-dialog-api-key]").focus();
    });
  });

  dialog.querySelectorAll("[data-dialog-close]").forEach((button) => button.addEventListener("click", () => dialog.close()));
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) dialog.close();
  });
  dialog.addEventListener("close", () => {
    dialog.querySelector("[data-dialog-api-key]").value = "";
  });
});
