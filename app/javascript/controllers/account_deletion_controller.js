import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confirmation", "password", "submit"]
  static values = { passwordRequired: Boolean }

  connect() {
    this.updateSubmitState()
  }

  updateSubmitState() {
    const allConfirmed = this.confirmationTargets.length === 4 &&
      this.confirmationTargets.every((checkbox) => checkbox.checked)
    const passwordPresent = !this.passwordRequiredValue ||
      (this.hasPasswordTarget && this.passwordTarget.value.trim() !== "")

    this.submitTarget.disabled = !(allConfirmed && passwordPresent)
  }
}
