import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static prefecturesByRegion = {
    北海道: ["北海道"],
    東北: ["青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県"],
    関東: ["茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県"],
    中部: ["新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県", "三重県"],
    近畿: ["滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県"],
    中国: ["鳥取県", "島根県", "岡山県", "広島県", "山口県"],
    四国: ["徳島県", "香川県", "愛媛県", "高知県"],
    九州: ["福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県"],
    沖縄: ["沖縄県"]
  }

  static values = {
    estimateAmountsByName: Object
  }

  static targets = [
    "amountInput",
    "container",
    "customNameEstimateMessage",
    "destroyField",
    "item",
    "movingEstimateFields",
    "movingFromPrefecture",
    "movingToPrefecture",
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

  applyMovingEstimate(event) {
    const item = event.currentTarget.closest("[data-nested-form-target='item']")
    const fromPrefecture = item.querySelector("[data-nested-form-target~='movingFromPrefecture']").value
    const toPrefecture = item.querySelector("[data-nested-form-target~='movingToPrefecture']").value

    if (!fromPrefecture || !toPrefecture) {
      return
    }

    const amountInput = item.querySelector("[data-nested-form-target~='amountInput']")
    const estimateAmount = this.movingEstimateAmount(fromPrefecture, toPrefecture)

    amountInput.value = estimateAmount
    item.dataset.autoEstimateAmount = estimateAmount
  }

  movingEstimateAmount(fromPrefecture, toPrefecture) {
    if (fromPrefecture === toPrefecture) {
      return 30000
    }

    if ([fromPrefecture, toPrefecture].some((prefecture) => ["北海道", "沖縄県"].includes(prefecture))) {
      return 150000
    }

    return this.regionFor(fromPrefecture) === this.regionFor(toPrefecture) ? 50000 : 100000
  }

  regionFor(prefecture) {
    return Object.keys(this.constructor.prefecturesByRegion).find((region) => (
      this.constructor.prefecturesByRegion[region].includes(prefecture)
    ))
  }

  toggleMovingEstimateFields(item) {
    if (!item) {
      return
    }

    const fields = item.querySelector("[data-nested-form-target~='movingEstimateFields']")

    if (!fields) {
      return
    }

    const nameSelect = item.querySelector("[data-nested-form-target~='nameSelect']")
    const statusSelect = item.querySelector("[data-nested-form-target~='statusSelect']")
    const shouldShow = item.dataset.category === "moving" &&
      nameSelect.value === "引っ越し業者費用" &&
      statusSelect.value === "estimated"

    fields.classList.toggle("d-none", !shouldShow)
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
