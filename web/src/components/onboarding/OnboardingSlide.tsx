interface OnboardingSlideProps {
  icon: string
  iconClass?: string
  title: string
  paragraphs: string[]
}

export function OnboardingSlide({ icon, iconClass = 'onboarding-icon-blue', title, paragraphs }: OnboardingSlideProps) {
  return (
    <div className="onboarding-slide">
      <span className={`onboarding-icon ${iconClass}`} aria-hidden>
        {icon}
      </span>
      <h2 className="onboarding-title">{title}</h2>
      <div className="onboarding-paragraphs">
        {paragraphs.map((p) => (
          <p key={p.slice(0, 32)}>{p}</p>
        ))}
      </div>
    </div>
  )
}
