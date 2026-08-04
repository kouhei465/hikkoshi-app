import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    estimateAmountsByName: Object,
    movingEstimateUrl: String
  }

  static targets = [
    "amountInput",
    "container",
    "customNameEstimateMessage",
    "destroyField",
    "item",
    "movingDestination",
    "movingDistance",
    "movingEstimateButton",
    "movingEstimateError",
    "movingEstimateFields",
    "movingEstimateResult",
    "movingOrigin",
    "nameSelect",
    "rentEstimateMessage",
    "template"
  ]

  connect() {
    this.itemTargets.forEach((item) => {
      this.toggleMovingEstimateFields(item)
      this.toggleCustomNameEstimateMessage(item)
    })
  }

  add(event) {
    const category = event.params.category
    const template = this.templateTargets.find((target) => target.dataset.category === category)
    const container = this.containerTargets.find((target) => target.dataset.category === category)
    const timestamp = new Date().getTime()

    container.insertAdjacentHTML(
      "beforeend",
      template.innerHTML.replaceAll(`NEW_RECORD_${category}`, timestamp)
    )

    this.toggleMovingEstimateFields(container.lastElementChild)
  }

  remove(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")

    if (item.dataset.newRecord === "true") {
      item.remove()
      return
    }

    item.querySelector("[data-nested-form-target='destroyField']").value = "1"
    item.hidden = true
  }

  preventAccidentalSubmit(event) {
    const target = event.target
    const buttonInputTypes = ["button", "submit", "image", "reset"]

    if (event.isComposing || target.tagName !== "INPUT" || buttonInputTypes.includes(target.type)) {
      return
    }

    event.preventDefault()
  }

  applyEstimateAmount(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")
    const amountInput = item.querySelector("[data-nested-form-target~='amountInput']")

    this.hideCustomNameEstimateMessage(item)
    this.hideRentEstimateMessage(item)
    this.toggleMovingEstimateFields(item)

    if (event.currentTarget.value !== "estimated") {
      return
    }

    if (!this.hasKnownName(item)) {
      this.clearAutoEstimateAmount(item, amountInput)
      this.showCustomNameEstimateMessage(item)
      return
    }

    if (amountInput.value) {
      return
    }

    const estimateAmount = this.estimateAmountFor(item)

    if (estimateAmount) {
      amountInput.value = estimateAmount
      item.dataset.autoEstimateAmount = estimateAmount
      return
    }

    if (this.needsRentAmount(item)) {
      this.showRentEstimateMessage(item)
    }
  }

  clearRentEstimateMessage(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")

    this.hideRentEstimateMessage(item)
  }

  toggleCustomNameEstimateMessage(item) {
    const statusSelect = item.querySelector("[data-nested-form-target~='statusSelect']")
    const shouldShow = statusSelect.value === "estimated" && !this.hasKnownName(item)

    item.querySelector("[data-nested-form-target~='customNameEstimateMessage']")
      .classList.toggle("d-none", !shouldShow)
  }

  hasKnownName(item) {
    const nameInput = item.querySelector("[data-nested-form-target~='nameSelect']")
    const datalist = document.getElementById(nameInput.getAttribute("list"))

    return Array.from(datalist?.options || []).some((option) => option.value === nameInput.value)
  }

  clearAutoEstimateAmount(item, amountInput) {
    if (item.dataset.autoEstimateAmount === amountInput.value) {
      amountInput.value = ""
    }

    delete item.dataset.autoEstimateAmount
  }

  async calculateMovingEstimate(event) {
    event.preventDefault()

    const item = event.currentTarget.closest("[data-nested-form-target='item']")
    const origin = item.querySelector("[data-nested-form-target~='movingOrigin']").value.trim()
    const destination = item.querySelector("[data-nested-form-target~='movingDestination']").value.trim()

    this.hideMovingEstimateFeedback(item)

    if (!origin || !destination) {
      const message = !origin ? "出発地を入力してください" : "到着地を入力してください"
      this.showMovingEstimateError(item, message)
      return
    }

    const button = item.querySelector("[data-nested-form-target~='movingEstimateButton']")
    const amountInput = item.querySelector("[data-nested-form-target~='amountInput']")
    button.disabled = true
    button.textContent = "計算中…"

    try {
      const headers = {
        "Accept": "application/json",
        "Content-Type": "application/json"
      }
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

      if (csrfToken) {
        headers["X-CSRF-Token"] = csrfToken
      }

      const response = await fetch(this.movingEstimateUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers,
        body: JSON.stringify({ origin, destination })
      })
      const payload = await response.json().catch(() => ({}))

      if (!response.ok) {
        this.showMovingEstimateError(item, payload.error || "距離を計算できませんでした")
        return
      }

      if (!this.validMovingEstimate(payload)) {
        throw new Error("距離を計算できませんでした")
      }

      if (!this.shouldShowMovingEstimateFields(item)) {
        return
      }

      amountInput.value = payload.estimated_amount
      item.dataset.autoEstimateAmount = payload.estimated_amount

      const distance = item.querySelector("[data-nested-form-target~='movingDistance']")
      distance.textContent = payload.distance_km.toLocaleString("ja-JP", { maximumFractionDigits: 1 })
      item.querySelector("[data-nested-form-target~='movingEstimateResult']").classList.remove("d-none")
    } catch (_error) {
      this.showMovingEstimateError(item, "距離を計算できませんでした。時間をおいて再度お試しください")
    } finally {
      button.disabled = false
      button.textContent = "距離から概算する"
    }
  }

  validMovingEstimate(payload) {
    return Number.isInteger(payload.distance_meters) &&
      payload.distance_meters > 0 &&
      Number.isFinite(payload.distance_km) &&
      payload.distance_km >= 0 &&
      Number.isInteger(payload.estimated_amount) &&
      payload.estimated_amount > 0
  }

  hideMovingEstimateFeedback(item) {
    item.querySelector("[data-nested-form-target~='movingEstimateResult']").classList.add("d-none")
    item.querySelector("[data-nested-form-target~='movingEstimateError']").classList.add("d-none")
  }

  showMovingEstimateError(item, message) {
    const error = item.querySelector("[data-nested-form-target~='movingEstimateError']")
    error.textContent = message
    error.classList.remove("d-none")
  }

  toggleMovingEstimateFields(item) {
    if (!item) {
      return
    }

    const fields = item.querySelector("[data-nested-form-target~='movingEstimateFields']")

    if (!fields) {
      return
    }

    fields.classList.toggle("d-none", !this.shouldShowMovingEstimateFields(item))
  }

  shouldShowMovingEstimateFields(item) {
    const nameSelect = item.querySelector("[data-nested-form-target~='nameSelect']")
    const statusSelect = item.querySelector("[data-nested-form-target~='statusSelect']")

    return item.dataset.category === "moving" &&
      nameSelect.value === "引っ越し業者費用" &&
      statusSelect.value === "estimated"
  }

  estimateAmountFor(item) {
    if (this.needsMovingDistanceEstimate(item)) {
      return
    }

    if (this.needsRentAmount(item)) {
      return this.rentAmount()
    }

    const nameInput = item.querySelector("[data-nested-form-target~='nameSelect']")
    const estimateAmountByName = this.estimateAmountsByNameValue[nameInput.value]

    return estimateAmountByName || item.dataset.referenceEstimateAmount
  }

  needsRentAmount(item) {
    const nameSelect = item.querySelector("[data-nested-form-target~='nameSelect']")

    return item.dataset.category === "rent" && nameSelect.value !== "家賃"
  }

  needsMovingDistanceEstimate(item) {
    const nameSelect = item.querySelector("[data-nested-form-target~='nameSelect']")

    return item.dataset.category === "moving" && nameSelect.value === "引っ越し業者費用"
  }

  rentAmount() {
    const rentItem = this.itemTargets.find((item) => {
      const nameSelect = item.querySelector("[data-nested-form-target~='nameSelect']")
      const destroyField = item.querySelector("[data-nested-form-target~='destroyField']")

      return item.dataset.category === "rent" &&
        nameSelect.value === "家賃" &&
        destroyField.value !== "1" &&
        !item.hidden
    })

    return rentItem?.querySelector("[data-nested-form-target~='amountInput']").value
  }

  showRentEstimateMessage(item) {
    item.querySelector("[data-nested-form-target~='rentEstimateMessage']").classList.remove("d-none")
  }

  hideRentEstimateMessage(item) {
    item.querySelector("[data-nested-form-target~='rentEstimateMessage']").classList.add("d-none")
  }

  showCustomNameEstimateMessage(item) {
    item.querySelector("[data-nested-form-target~='customNameEstimateMessage']").classList.remove("d-none")
  }

  hideCustomNameEstimateMessage(item) {
    item.querySelector("[data-nested-form-target~='customNameEstimateMessage']").classList.add("d-none")
  }

  handleNameChange(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")
    const amountInput = item.querySelector("[data-nested-form-target~='amountInput']")
    const statusSelect = item.querySelector("[data-nested-form-target~='statusSelect']")

    this.hideCustomNameEstimateMessage(item)
    this.hideRentEstimateMessage(item)
    this.toggleMovingEstimateFields(item)

    const previousAutoEstimateAmount = item.dataset.autoEstimateAmount
    const amountWasAutoFilled = previousAutoEstimateAmount && amountInput.value === previousAutoEstimateAmount

    if (!this.hasKnownName(item)) {
      this.clearAutoEstimateAmount(item, amountInput)

      if (statusSelect.value === "estimated") {
        this.showCustomNameEstimateMessage(item)
      }

      return
    }

    if (statusSelect.value !== "estimated") {
      return
    }

    if (amountInput.value && !amountWasAutoFilled) {
      return
    }

    const estimateAmount = this.estimateAmountFor(item)

    if (estimateAmount) {
      amountInput.value = estimateAmount
      item.dataset.autoEstimateAmount = estimateAmount
      return
    }

    amountInput.value = ""
    delete item.dataset.autoEstimateAmount

    if (this.needsRentAmount(item)) {
      this.showRentEstimateMessage(item)
    }
  }
}
