import React, {useContext} from 'react'
import { ChallengeTab } from "../ChallengeTab"
import { ApiUrlContext } from '../../ApiUrlContext'

export const Winners = ({challenge, challengePhases, print}) => {
  const { imageBase } = useContext(ApiUrlContext)

  const renderOverviewImage = (phaseWinner) => {
    if (phaseWinner.overview_image_path) {
      return (
        <img
          src={`${imageBase}${encodeURIComponent(phaseWinner.overview_image_path)}`}
          alt="Phase Winner image"
          title="Phase Winner image"
          className="phase-winner-image mt-3"
        />
      )
    }
  }

  const renderWinners = (winners) => {
    return winners.map(winner => {
      const {id, image_path, name, place_title} = winner
      return (
        <div key={id} className="d-flex flex-row align-items-center usa-tbm-1rem">
          {image_path && (<img src={`${imageBase}${encodeURIComponent(winner.image_path)}`} alt="winner image" title="winner image" className="phase-winner-image me-3" />)}
          {name && <p>{name}</p>}
          {place_title && <p>{` - ${place_title}`}</p>}
        </div>
      )
    })
  }

  const hasPhaseWinnerData = (phaseWinner) => {
    return (
      (!!phaseWinner.overview && phaseWinner.overview != "") ||
      !!phaseWinner.overview_image_path ||
      (!!phaseWinner.winners && phaseWinner.winners.length > 0)
    )
  }

  const renderPhaseWinners = () => {
    return challengePhases.map(phase => {
      const phaseWinner = phase.phase_winner
      if (phaseWinner && Object.keys(phaseWinner).length >= 1 && hasPhaseWinnerData(phaseWinner)) {
        return (
          <div key={phaseWinner.id || idx } className="usa-card">
            <div className="usa-card-body ql-editor">
              {renderOverviewImage(phaseWinner)}
              <h1 className="usa-tbm-1rem">{phaseWinner.phase_title}</h1>
              <div className="usa-tbm-1rem" dangerouslySetInnerHTML={{ __html: phaseWinner.overview }}></div>
              {phaseWinner.winners && phaseWinner.winners.length >= 1 &&
                <div className="winners-section">{renderWinners(phaseWinner.winners)}</div>
              }
            </div>
          </div>
        )
      }
    })
  }

  return (
    <ChallengeTab label="Winners" downloadsLabel="Additional winner documents" section="winners" challenge={challenge} print={print}>
      {renderPhaseWinners()}
    </ChallengeTab>
  )
}
