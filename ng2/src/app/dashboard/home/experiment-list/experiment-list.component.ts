import {
  Component,
  OnInit,
  HostListener,
  ElementRef
} from '@angular/core'

import {
  ExperimentService,
  ExperimentList
} from '../../../shared'

const ESCAPE_KEYCODE = 27;

@Component({
  selector: 'experiment-list',
  templateUrl: './experiment-list.component.html',
  styleUrls: ['./experiment-list.component.scss']
})
export class ExperimentListComponent implements OnInit {

  experiments: ExperimentListItem[]
  editing: boolean

  constructor(private expService: ExperimentService, private el: ElementRef) {

  }

  @HostListener('document:keydown', ['$event']) onKeydownHandler(event: KeyboardEvent) {
    let code = +event.code || event.keyCode
    if (code === ESCAPE_KEYCODE) {
      this.editing = false
      this.experiments.forEach(exp => {
        exp.confirmDelete = false
      })
    }
  }

  ngOnInit() {
    this.expService.getExperiments().subscribe((experiments: ExperimentList[]) => {
      this.experiments = experiments.map(exp => {
        return {
          model: exp,
          confirmDelete: false
        }
      })
    })
  }

  toggleEditing() {
    this.editing = !this.editing
  }

  confirmDelete(exp: ExperimentListItem, index: number) {
    exp.confirmDelete = true;
    let li: HTMLLIElement = this.el.nativeElement.querySelectorAll('li.exp-list-item')[index]
    let input: HTMLInputElement = li.querySelector('input')
    input.focus()
  }

  focusOut(exp: ExperimentListItem) {
    exp.confirmDelete = false
  }

}

export interface ExperimentListItem {
  model: ExperimentList,
  confirmDelete: boolean
}