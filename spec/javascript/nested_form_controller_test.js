import assert from "node:assert/strict"
import test from "node:test"

import NestedFormController from "../../app/javascript/controllers/nested_form_controller.js"

const classList = (...initialClasses) => {
  const classes = new Set(initialClasses)

  return {
    add(name) { classes.add(name) },
    remove(name) { classes.delete(name) },
    contains(name) { return classes.has(name) },
    toggle(name, force) {
      if (force) {
        classes.add(name)
      } else {
        classes.delete(name)
      }
    }
  }
}

const input = (initialValue = "") => ({
  _value: initialValue,
  get value() { return this._value },
  set value(value) { this._value = String(value) }
})

const itemFor = ({ category = "moving", name = "段ボール", amount = "", status = "estimated", newRecord = "true" } = {}) => {
  const fields = {
    nameSelect: { value: name, getAttribute: () => "cost-names" },
    amountInput: input(amount),
    statusSelect: input(status),
    destroyField: input("0"),
    movingOrigin: input("東京駅"),
    movingDestination: input("東京スカイツリー"),
    movingEstimateButton: { disabled: false, textContent: "距離から概算する" },
    movingDistance: { textContent: "" },
    movingEstimateFields: { classList: classList("d-none") },
    movingEstimateResult: { classList: classList("d-none") },
    movingEstimateError: { classList: classList("d-none"), textContent: "" },
    customNameEstimateMessage: { classList: classList("d-none") },
    rentEstimateMessage: { classList: classList("d-none") }
  }
  // ブラウザのinput.valueとdatasetと同じく、代入した金額を文字列として扱う。
  const dataset = new Proxy({ category, newRecord }, {
    set(target, key, value) {
      target[key] = String(value)
      return true
    }
  })
  const item = {
    dataset,
    hidden: false,
    removed: false,
    remove() { this.removed = true },
    querySelector(selector) {
      const targetName = selector.match(/data-nested-form-target~?='([^']+)'/)[1]
      return fields[targetName]
    }
  }

  return { item, fields }
}

const eventFor = (item, currentTarget = {}) => ({
  preventDefault() {},
  currentTarget: { closest: () => item, ...currentTarget }
})

const controllerFor = (items = []) => {
  const controller = Object.create(NestedFormController.prototype)
  Object.defineProperties(controller, {
    itemTargets: { value: items },
    estimateAmountsByNameValue: { value: { "段ボール": 3000, "梱包資材": 5000 } },
    movingEstimateUrlValue: { value: "/moving_estimate" }
  })

  return controller
}

const withDocument = (callback) => {
  const originalDocument = globalThis.document
  globalThis.document = {
    getElementById: () => ({
      options: ["段ボール", "梱包資材", "家賃", "敷金", "引っ越し業者費用"].map((value) => ({ value }))
    }),
    querySelector: () => null
  }

  try {
    callback()
  } finally {
    globalThis.document = originalDocument
  }
}

const keydownEventFor = (target) => ({
  target,
  defaultPrevented: false,
  preventDefault() {
    this.defaultPrevented = true
  }
})

test("通常のinputでEnterを押すと送信を防止する", () => {
  const controller = Object.create(NestedFormController.prototype)
  const event = keydownEventFor({ tagName: "INPUT", type: "text" })

  controller.preventAccidentalSubmit(event)

  assert.equal(event.defaultPrevented, true)
})

test("日本語IMEの変換中はEnterによる変換確定を妨げない", () => {
  const controller = Object.create(NestedFormController.prototype)
  const event = keydownEventFor({ tagName: "INPUT", type: "text" })
  event.isComposing = true

  controller.preventAccidentalSubmit(event)

  assert.equal(event.defaultPrevented, false)
})

test("submitボタンでは送信を妨げない", () => {
  const controller = Object.create(NestedFormController.prototype)
  const event = keydownEventFor({ tagName: "INPUT", type: "submit" })

  controller.preventAccidentalSubmit(event)

  assert.equal(event.defaultPrevented, false)
})

test("type=buttonのボタン操作を妨げない", () => {
  const controller = Object.create(NestedFormController.prototype)
  const event = keydownEventFor({ tagName: "BUTTON", type: "button" })

  controller.preventAccidentalSubmit(event)

  assert.equal(event.defaultPrevented, false)
})

test("textareaのEnterによる改行を妨げない", () => {
  const controller = Object.create(NestedFormController.prototype)
  const event = keydownEventFor({ tagName: "TEXTAREA", type: "textarea" })

  controller.preventAccidentalSubmit(event)

  assert.equal(event.defaultPrevented, false)
})

test("指定カテゴリに行を追加し、新しい行の距離入力欄を表示する", () => {
  const { item, fields } = itemFor({ name: "引っ越し業者費用" })
  const container = {
    dataset: { category: "moving" },
    lastElementChild: item,
    insertAdjacentHTML(position, html) {
      this.position = position
      this.html = html
    }
  }
  const otherContainer = { dataset: { category: "rent" } }
  const controller = controllerFor()
  Object.defineProperties(controller, {
    templateTargets: { value: [{ dataset: { category: "moving" }, innerHTML: "items[NEW_RECORD_moving][name] items[NEW_RECORD_moving][amount]" }] },
    containerTargets: { value: [otherContainer, container] }
  })

  controller.add({ params: { category: "moving" } })

  assert.equal(container.position, "beforeend")
  assert.match(container.html, /^items\[(\d+)\]\[name\] items\[\1\]\[amount\]$/)
  assert.equal(fields.movingEstimateFields.classList.contains("d-none"), false)
})

test("新しい行はDOMから削除し、保存済みの行は削除指定して非表示にする", () => {
  const newRow = itemFor()
  const savedRow = itemFor({ newRecord: "false" })
  const controller = controllerFor()

  controller.remove(eventFor(newRow.item))
  controller.remove(eventFor(savedRow.item))

  assert.equal(newRow.item.removed, true)
  assert.equal(savedRow.item.removed, false)
  assert.equal(savedRow.item.hidden, true)
  assert.equal(savedRow.fields.destroyField.value, "1")
})

test("概算を選ぶと空欄に目安金額を入れ、手入力済みの金額は保持する", () => {
  withDocument(() => {
    const emptyRow = itemFor()
    const manualRow = itemFor({ amount: "4500" })
    const controller = controllerFor()

    controller.applyEstimateAmount(eventFor(emptyRow.item, { value: "estimated" }))
    controller.applyEstimateAmount(eventFor(manualRow.item, { value: "estimated" }))

    assert.equal(emptyRow.fields.amountInput.value, "3000")
    assert.equal(emptyRow.item.dataset.autoEstimateAmount, "3000")
    assert.equal(manualRow.fields.amountInput.value, "4500")
  })
})

test("候補の変更時は自動入力した金額だけを更新する", () => {
  withDocument(() => {
    const autoRow = itemFor({ name: "梱包資材", amount: "3000" })
    autoRow.item.dataset.autoEstimateAmount = "3000"
    const manualRow = itemFor({ name: "梱包資材", amount: "4500" })
    manualRow.item.dataset.autoEstimateAmount = "3000"
    const controller = controllerFor()

    controller.handleNameChange(eventFor(autoRow.item))
    controller.handleNameChange(eventFor(manualRow.item))

    assert.equal(autoRow.fields.amountInput.value, "5000")
    assert.equal(autoRow.item.dataset.autoEstimateAmount, "5000")
    assert.equal(manualRow.fields.amountInput.value, "4500")
  })
})

test("自由入力の費用名では自動金額を消して案内し、手入力金額は保持する", () => {
  withDocument(() => {
    const autoRow = itemFor({ name: "特別な梱包資材", amount: "3000" })
    autoRow.item.dataset.autoEstimateAmount = "3000"
    const manualRow = itemFor({ name: "特別な梱包資材", amount: "4500" })
    manualRow.item.dataset.autoEstimateAmount = "3000"
    const controller = controllerFor()

    controller.handleNameChange(eventFor(autoRow.item))
    controller.handleNameChange(eventFor(manualRow.item))

    assert.equal(autoRow.fields.amountInput.value, "")
    assert.equal(autoRow.item.dataset.autoEstimateAmount, undefined)
    assert.equal(autoRow.fields.customNameEstimateMessage.classList.contains("d-none"), false)
    assert.equal(manualRow.fields.amountInput.value, "4500")
  })
})

test("家賃を使う概算では削除済みの家賃を除外して有効な行の金額を使う", () => {
  withDocument(() => {
    const deletedRent = itemFor({ category: "rent", name: "家賃", amount: "99999" })
    deletedRent.fields.destroyField.value = "1"
    const hiddenRent = itemFor({ category: "rent", name: "家賃", amount: "88888" })
    hiddenRent.item.hidden = true
    const activeRent = itemFor({ category: "rent", name: "家賃", amount: "80000" })
    const deposit = itemFor({ category: "rent", name: "敷金" })
    const controller = controllerFor([deletedRent.item, hiddenRent.item, activeRent.item, deposit.item])

    controller.applyEstimateAmount(eventFor(deposit.item, { value: "estimated" }))

    assert.equal(deposit.fields.amountInput.value, "80000")
  })
})

test("家賃が空欄の場合は金額を入れず入力を促す", () => {
  withDocument(() => {
    const deposit = itemFor({ category: "rent", name: "敷金" })
    const controller = controllerFor([deposit.item])

    controller.applyEstimateAmount(eventFor(deposit.item, { value: "estimated" }))

    assert.equal(deposit.fields.amountInput.value, "")
    assert.equal(deposit.fields.rentEstimateMessage.classList.contains("d-none"), false)
  })
})

test("距離計算が成功すると概算金額と距離を表示し、ボタンを戻す", async () => {
  const { item, fields } = itemFor({ name: "引っ越し業者費用" })
  const controller = controllerFor()
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  let request
  globalThis.document = { querySelector: () => ({ content: "csrf-token" }) }
  globalThis.fetch = async (url, options) => {
    request = { url, options }
    assert.equal(fields.movingEstimateButton.disabled, true)
    return {
      ok: true,
      json: async () => ({ distance_meters: 123400, distance_km: 123.4, estimated_amount: 60000 })
    }
  }

  try {
    await controller.calculateMovingEstimate(eventFor(item))
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
  }

  assert.equal(request.url, "/moving_estimate")
  assert.equal(request.options.credentials, "same-origin")
  assert.equal(request.options.headers["X-CSRF-Token"], "csrf-token")
  assert.deepEqual(JSON.parse(request.options.body), { origin: "東京駅", destination: "東京スカイツリー" })
  assert.equal(fields.amountInput.value, "60000")
  assert.equal(item.dataset.autoEstimateAmount, "60000")
  assert.equal(fields.movingDistance.textContent, "123.4")
  assert.equal(fields.movingEstimateResult.classList.contains("d-none"), false)
  assert.equal(fields.movingEstimateButton.disabled, false)
  assert.equal(fields.movingEstimateButton.textContent, "距離から概算する")
})

test("出発地が空欄の場合は通信せずエラーを表示して金額を保持する", async () => {
  const { item, fields } = itemFor({ name: "引っ越し業者費用", amount: "75000" })
  fields.movingOrigin.value = " "
  const controller = controllerFor()
  const originalFetch = globalThis.fetch
  let fetched = false
  globalThis.fetch = async () => { fetched = true }

  try {
    await controller.calculateMovingEstimate(eventFor(item))
  } finally {
    globalThis.fetch = originalFetch
  }

  assert.equal(fetched, false)
  assert.equal(fields.amountInput.value, "75000")
  assert.equal(fields.movingEstimateError.textContent, "出発地を入力してください")
  assert.equal(fields.movingEstimateError.classList.contains("d-none"), false)
})

test("距離計算の応答に金額が欠けていたら入力を保持し再試行を案内する", async () => {
  const { item, fields } = itemFor({ name: "引っ越し業者費用", amount: "75000" })
  const controller = controllerFor()
  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  globalThis.document = { querySelector: () => null }
  globalThis.fetch = async () => ({
    ok: true,
    json: async () => ({ distance_meters: 123400, distance_km: 123.4 })
  })

  try {
    await controller.calculateMovingEstimate(eventFor(item))
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
  }

  assert.equal(fields.amountInput.value, "75000")
  assert.equal(fields.movingEstimateError.textContent, "距離を計算できませんでした。時間をおいて再度お試しください")
  assert.equal(fields.movingEstimateError.classList.contains("d-none"), false)
  assert.equal(fields.movingEstimateResult.classList.contains("d-none"), true)
  assert.equal(fields.movingEstimateButton.disabled, false)
})

test("APIエラー時に入力済み金額を変更しない", async () => {
  const { item, fields } = itemFor({ name: "引っ越し業者費用", amount: "75000" })
  const controller = controllerFor()

  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  globalThis.document = { querySelector: () => null }
  globalThis.fetch = async () => ({
    ok: false,
    json: async () => ({ error: "郵便番号の形式が不正です" })
  })

  try {
    await controller.calculateMovingEstimate(eventFor(item))
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
  }

  assert.equal(fields.amountInput.value, "75000")
  assert.equal(fields.movingEstimateError.textContent, "郵便番号の形式が不正です")
  assert.equal(fields.movingEstimateError.classList.contains("d-none"), false)
  assert.equal(fields.movingEstimateButton.disabled, false)
})
