const form = document.querySelector("#item-form");
const itemsList = document.querySelector("#items");
const statusMessage = document.querySelector("#status");

async function request(path, options) {
  const response = await fetch(path, options);
  if (!response.ok) {
    const message = (await response.text()).trim();
    throw new Error(message || `Request failed (${response.status})`);
  }
  return response.status === 204 ? null : response.json();
}

function renderItems(items) {
  itemsList.replaceChildren();
  for (const item of items) {
    const row = document.createElement("li");
    row.className = "item";

    const details = document.createElement("div");
    const name = document.createElement("span");
    name.className = "item-name";
    name.textContent = item.name;
    const quantity = document.createElement("span");
    quantity.className = "item-quantity";
    quantity.textContent = ` · Qty ${item.quantity}`;
    details.append(name, quantity);

    const remove = document.createElement("button");
    remove.className = "delete";
    remove.type = "button";
    remove.textContent = "Remove";
    remove.setAttribute("aria-label", `Remove ${item.name}`);
    remove.addEventListener("click", async () => {
      try {
        await request(`/api/items/${item.id}`, { method: "DELETE" });
        statusMessage.textContent = "";
        await loadItems();
      } catch (error) {
        statusMessage.textContent = error.message;
      }
    });

    row.append(details, remove);
    itemsList.append(row);
  }
}

async function loadItems() {
  renderItems(await request("/api/items"));
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  statusMessage.textContent = "";
  const data = new FormData(form);
  try {
    await request("/api/items", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: data.get("name"),
        quantity: Number(data.get("quantity")),
      }),
    });
    form.reset();
    document.querySelector("#item-quantity").value = "1";
    await loadItems();
  } catch (error) {
    statusMessage.textContent = error.message;
  }
});

loadItems().catch((error) => {
  statusMessage.textContent = error.message;
});
