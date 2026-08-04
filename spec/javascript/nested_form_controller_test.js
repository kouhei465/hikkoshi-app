import assert from "node:assert/strict"
import test from "node:test"

import NestedFormController from "../../app/javascript/controllers/nested_form_controller.js"

const classList = () => ({
  add() {},
  remove() {}
})

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

test("APIエラー時に入力済み金額を変更しない", async () => {
  const amountInput = { value: "75000" }
  const button = { disabled: false, textContent: "距離から概算する" }
  const error = { classList: classList(), textContent: "" }
  const fields = {
    "[data-nested-form-target~='movingOrigin']": { value: "東京駅" },
    "[data-nested-form-target~='movingDestination']": { value: "東京スカイツリー" },
    "[data-nested-form-target~='movingEstimateButton']": button,
    "[data-nested-form-target~='amountInput']": amountInput,
    "[data-nested-form-target~='movingEstimateResult']": { classList: classList() },
    "[data-nested-form-target~='movingEstimateError']": error
  }
  const item = { querySelector: (selector) => fields[selector] }
  const event = {
    preventDefault() {},
    currentTarget: { closest: () => item }
  }
  const controller = Object.create(NestedFormController.prototype)
  Object.defineProperty(controller, "movingEstimateUrlValue", { value: "/moving_estimate" })

  const originalDocument = globalThis.document
  const originalFetch = globalThis.fetch
  globalThis.document = { querySelector: () => null }
  globalThis.fetch = async () => ({
    ok: false,
    json: async () => ({ error: "郵便番号の形式が不正です" })
  })

  try {
    await controller.calculateMovingEstimate(event)
  } finally {
    globalThis.document = originalDocument
    globalThis.fetch = originalFetch
  }

  assert.equal(amountInput.value, "75000")
  assert.equal(error.textContent, "郵便番号の形式が不正です")
  assert.equal(button.disabled, false)
})
