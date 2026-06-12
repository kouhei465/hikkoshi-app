import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    estimateAmountsByName: Object
  }

  static targets = [
    "amountInput",
    "container",
    "destroyField",
    "item",
    "nameSelect",
    "rentEstimateMessage",
    "template"
  ]

  add(event) {
    const category = event.params.category
    const template = this.templateTargets.find((target) => target.dataset.category === category)
    const container = this.containerTargets.find((target) => target.dataset.category === category)
    const timestamp = new Date().getTime()

    container.insertAdjacentHTML(
      "beforeend",
      template.innerHTML.replaceAll(`NEW_RECORD_${category}`, timestamp)
    )
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

  applyEstimateAmount(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")
    const amountInput = item.querySelector("[data-nested-form-target~='amountInput']")

    this.hideRentEstimateMessage(item)

    if (event.currentTarget.value !== "estimated" || amountInput.value) {
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

  estimateAmountFor(item) {
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

  handleNameChange(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")
    const amountInput = item.querySelector("[data-nested-form-target~='amountInput']")
    const statusSelect = item.querySelector("[data-nested-form-target~='statusSelect']")

    this.hideRentEstimateMessage(item)

    if (statusSelect.value !== "estimated") {
      return
    }

    const previousAutoEstimateAmount = item.dataset.autoEstimateAmount
    const amountWasAutoFilled = previousAutoEstimateAmount && amountInput.value === previousAutoEstimateAmount

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
