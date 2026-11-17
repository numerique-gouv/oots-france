# The student status API Particulier returned, as the preview space shows it to
# the user: their identity, then each admission of the year. Chapter 4.10
# §5.1, step 20, « The evidence may need to be transformed to allow the user to
# preview it. For example, if it is in a structured format ».
#
# The values are shown as the registry wrote them — dates included —, so that
# what the user decides on is what the answer will carry.
class StudentStatusComponent < ViewComponent::Base
  def initialize(student_status:)
    @student_status = student_status
    super()
  end

  delegate :admissions, to: :@student_status

  def card_identity = StudentStatus::CardIdentity.from(@student_status.identity)

  # The registry's own names for what it holds: `nom_naissance` is a birth name.
  def identity_labels
    {
      family_name: t('components.student_status.family_name'),
      given_name: t('components.student_status.given_name'),
      birthdate: t('components.student_status.date_of_birth'),
    }
  end

  def enrolment(admission) = t("components.student_status.#{admission.enrolled ? 'enrolled' : 'admitted'}")
end
